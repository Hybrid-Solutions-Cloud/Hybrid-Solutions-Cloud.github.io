#Requires -Version 7.0
<#
.SYNOPSIS
    Audit the public mail-authentication posture (MX, SPF, DKIM, DMARC) of HCS domains.

.DESCRIPTION
    HCS has no DNS-as-code repo, so the Cloudflare zones that carry SPF, DKIM and
    DMARC for tenant domains are hand-managed in the dashboard with no committed
    source of truth. That makes a question like "what did we actually configure on
    this domain?" unanswerable from the repos, and it puts DNS outside the
    declarative, PR-reviewed model the infrastructure standard requires.

    This script closes the visibility half of that gap. It resolves the live public
    records over DNS-over-HTTPS, optionally reconciles them against the records
    Cloudflare holds for the zone, and asserts each one against the expected posture
    declared in config/mail-posture.yml. Findings are printed as a PASS/WARN/FAIL
    table and written to a log file.

    It is strictly read-only: it never writes a DNS record. Run it from a host with
    outbound access to the DoH resolver and to the Cloudflare API.

    Checks performed per domain:
      MX     - present and non-null when the domain sends mail; null MX ('.') when it does not.
      SPF    - exactly one v=spf1 record, required includes present, correct all-qualifier,
               and the RFC 7208 ten-DNS-lookup limit not exceeded.
      DKIM   - each expected selector resolves.
      DMARC  - record present, policy at or stricter than expected, and every rua=
               address on the allow-list. An off-tenant rua= address is a FAIL: it
               means aggregate reports for a tenant domain leave that tenant.

.PARAMETER ConfigPath
    Path to the YAML config. Defaults to config/mail-posture.yml relative to the
    repo root. If the file is missing it is bootstrapped from the committed example
    and the script fails cleanly so the operator can fill it in.

.PARAMETER Domain
    Audit only this domain from the config instead of every domain in it.

.PARAMETER SkipCloudflare
    Skip the Cloudflare zone reconciliation and audit public DNS only. Use when no
    API token is available, or from a host that can reach a DoH resolver but not the
    Cloudflare API.

.PARAMETER LogPath
    Override the log file path. Defaults to a timestamped file under the temp directory.

.PARAMETER DryRun
    Run every lookup and evaluation but suppress the Cloudflare API calls, reporting
    what would have been requested. The script is read-only regardless; this exists
    to rehearse a run without spending API quota or needing a token.

.NOTES
    Author  : Kristopher Turner
    Contact : kris@hybridsolutions.cloud

    ScriptVersion    = "1.0.0"
    TaskReference    = "platform/dns-mail-posture/audit"
    DocumentationRef = "docs/dns-mail-posture.md"
    LastUpdated      = "2026-09-05"
    UpdatedBy        = "Kristopher Turner"
    ChangeLog        = @(
        "1.0.0 - 2026-09-05 - Initial implementation"
    )
#>

[CmdletBinding()]
param(
    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$ConfigPath = (Join-Path (Split-Path $PSScriptRoot -Parent) 'config/mail-posture.yml'),

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$Domain,

    [Parameter()]
    [string]$LogPath,

    [switch]$SkipCloudflare,

    [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:logFile  = if ($LogPath) { $LogPath } else {
    Join-Path ([System.IO.Path]::GetTempPath()) "hcs-$(Split-Path $PSCommandPath -LeafBase)-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
}
$script:findings = [System.Collections.Generic.List[pscustomobject]]::new()

# === Functions ===

function Write-Log {
    param([string]$Message, [string]$Level = 'INFO')
    $ts   = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $line = "[$ts] [$Level] $Message"
    $line | Out-File -FilePath $script:logFile -Append -Encoding utf8
    switch ($Level) {
        'PASS'    { Write-Host $line -ForegroundColor Green }
        'FAIL'    { Write-Host $line -ForegroundColor Red }
        'WARN'    { Write-Host $line -ForegroundColor Yellow }
        'HEADER'  { Write-Host $line -ForegroundColor Cyan }
        'VERBOSE' { Write-Verbose $line }
        'DEBUG'   { Write-Debug   $line }
        default   { Write-Host $line }
    }
}

function Add-Finding {
    param(
        [Parameter(Mandatory)][string]$DomainName,
        [Parameter(Mandatory)][string]$Check,
        [Parameter(Mandatory)][ValidateSet('PASS', 'WARN', 'FAIL')][string]$Status,
        [Parameter(Mandatory)][string]$Detail
    )
    $script:findings.Add([pscustomobject]@{
        Domain = $DomainName
        Check  = $Check
        Status = $Status
        Detail = $Detail
    })
    Write-Log "[$DomainName] $Check - $Detail" $Status
}

function Import-RequiredModule {
    param([Parameter(Mandatory)][string]$Name)
    if (-not (Get-Module -Name $Name -ListAvailable)) {
        Write-Log "Installing '$Name' module..." 'HEADER'
        Install-Module -Name $Name -Force -Scope CurrentUser
    }
    Import-Module $Name
}

function Resolve-KeyVaultRef {
    param([string]$KvUri)
    if ($KvUri -notmatch '^keyvault://([^/]+)/(.+)$') {
        Write-Log "Not a Key Vault URI: $KvUri" 'WARN'
        return $null
    }
    $vaultName  = $Matches[1]
    $secretName = $Matches[2]

    if (Get-Module -Name Az.KeyVault -ListAvailable -ErrorAction SilentlyContinue) {
        try {
            $secret = Get-AzKeyVaultSecret -VaultName $vaultName -Name $secretName -AsPlainText -ErrorAction Stop
            if ($secret) { Write-Log "Secret '$secretName' retrieved (Az.KeyVault)." 'PASS'; return $secret }
        } catch { Write-Log "Az.KeyVault failed: $_" 'WARN' }
    }

    try {
        $tmpErr = [System.IO.Path]::GetTempFileName()
        $val    = (& az keyvault secret show --vault-name $vaultName --name $secretName --query value --output tsv --only-show-errors 2>$tmpErr)
        $azErr  = (Get-Content $tmpErr -Raw -ErrorAction SilentlyContinue).Trim()
        Remove-Item $tmpErr -ErrorAction SilentlyContinue
        if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($val)) {
            Write-Log "Secret '$secretName' retrieved (az CLI)." 'PASS'
            return $val
        }
        $detail = if ($azErr) { ": $azErr" } else { " (exit $LASTEXITCODE)" }
        Write-Log "az CLI failed$detail." 'WARN'
    } catch { Write-Log "az CLI exception: $_" 'WARN' }

    return $null
}

function Get-DnsRecord {
    <#
        Resolve a record over DNS-over-HTTPS. Returns an array of normalised strings.
        TXT answers arrive quoted and long values arrive as multiple concatenated
        character-strings, so both are unwrapped here.
    #>
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][string]$Type,
        [Parameter(Mandatory)][string]$Endpoint
    )
    try {
        $uri      = "{0}?name={1}&type={2}" -f $Endpoint, [uri]::EscapeDataString($Name), $Type
        $response = Invoke-RestMethod -Uri $uri -Headers @{ accept = 'application/dns-json' } -TimeoutSec 20
    } catch {
        Write-Log "DoH lookup failed for $Type $Name : $($_.Exception.Message)" 'WARN'
        return @()
    }

    if (-not ($response.PSObject.Properties.Name -contains 'Answer')) { return @() }

    return @($response.Answer | Where-Object { $_.data } | ForEach-Object {
        $data = $_.data
        if ($Type -eq 'TXT') {
            # '"part one" "part two"' -> 'part onepart two'
            $chunks = [regex]::Matches($data, '"([^"]*)"')
            if ($chunks.Count -gt 0) {
                $data = -join ($chunks | ForEach-Object { $_.Groups[1].Value })
            } else {
                $data = $data.Trim('"')
            }
        }
        $data.Trim()
    })
}

function Get-CloudflareZoneRecord {
    param(
        [Parameter(Mandatory)][string]$ZoneName,
        [Parameter(Mandatory)][string]$ApiToken,
        [Parameter(Mandatory)][string]$ApiBaseUrl
    )
    $headers = @{ Authorization = "Bearer $ApiToken"; 'Content-Type' = 'application/json' }
    try {
        $zoneUri  = "{0}/zones?name={1}" -f $ApiBaseUrl, [uri]::EscapeDataString($ZoneName)
        $zoneResp = Invoke-RestMethod -Uri $zoneUri -Headers $headers -TimeoutSec 30
        if (-not $zoneResp.success -or $zoneResp.result.Count -eq 0) {
            Write-Log "Cloudflare zone '$ZoneName' not found or token lacks Zone:Read." 'WARN'
            return @()
        }
        $zoneId  = $zoneResp.result[0].id
        $recUri  = "{0}/zones/{1}/dns_records?per_page=100" -f $ApiBaseUrl, $zoneId
        $recResp = Invoke-RestMethod -Uri $recUri -Headers $headers -TimeoutSec 30
        if (-not $recResp.success) {
            Write-Log "Cloudflare DNS record list failed for '$ZoneName'." 'WARN'
            return @()
        }
        Write-Log "Cloudflare returned $($recResp.result.Count) records for '$ZoneName'." 'PASS'
        return @($recResp.result)
    } catch {
        Write-Log "Cloudflare API call failed for '$ZoneName': $($_.Exception.Message)" 'WARN'
        return @()
    }
}

function Test-MxPosture {
    param([Parameter(Mandatory)]$DomainConfig, [Parameter(Mandatory)][string]$Endpoint)

    $name    = $DomainConfig.name
    $records = Get-DnsRecord -Name $name -Type 'MX' -Endpoint $Endpoint
    $isNull  = ($records.Count -eq 1) -and ($records[0] -match '^\s*0\s+\.?$')

    if ($DomainConfig.sends_mail) {
        if ($records.Count -eq 0) {
            Add-Finding $name 'MX' 'FAIL' 'Domain is declared as sending mail but publishes no MX record.'
        } elseif ($isNull) {
            Add-Finding $name 'MX' 'FAIL' 'Domain is declared as sending mail but publishes a null MX, which blackholes inbound mail.'
        } else {
            Add-Finding $name 'MX' 'PASS' "MX present: $($records -join '; ')"
        }
    } else {
        if ($isNull) {
            Add-Finding $name 'MX' 'PASS' 'Null MX published for a non-sending domain.'
        } else {
            Add-Finding $name 'MX' 'WARN' "Domain is declared as non-sending but publishes MX: $($records -join '; ')"
        }
    }
}

function Test-SpfPosture {
    param([Parameter(Mandatory)]$DomainConfig, [Parameter(Mandatory)][string]$Endpoint)

    $name = $DomainConfig.name
    $txt  = Get-DnsRecord -Name $name -Type 'TXT' -Endpoint $Endpoint
    $spf  = @($txt | Where-Object { $_ -match '^v=spf1\b' })

    if ($spf.Count -eq 0) {
        Add-Finding $name 'SPF' 'FAIL' 'No v=spf1 record published. Anyone can send as this domain and pass SPF-neutral.'
        return
    }
    if ($spf.Count -gt 1) {
        Add-Finding $name 'SPF' 'FAIL' "$($spf.Count) v=spf1 records published. RFC 7208 permits exactly one; multiple records cause a permerror."
        return
    }

    $record = $spf[0]
    Add-Finding $name 'SPF' 'PASS' "Single SPF record: $record"

    if ($DomainConfig.sends_mail) {
        foreach ($include in @($DomainConfig.expected_spf_includes)) {
            if ($record -match [regex]::Escape("include:$include")) {
                Add-Finding $name "SPF include:$include" 'PASS' 'Required include present.'
            } else {
                Add-Finding $name "SPF include:$include" 'FAIL' "Required include missing. Mail sent via this platform will fail SPF."
            }
        }
    }

    $expectedAll = [string]$DomainConfig.expected_spf_all
    if ($record -match '(?<qualifier>[-~?+]all)\s*$') {
        $actualAll = $Matches['qualifier']
        if ($actualAll -eq $expectedAll) {
            Add-Finding $name 'SPF all-qualifier' 'PASS' "Terminates with '$actualAll' as expected."
        } else {
            Add-Finding $name 'SPF all-qualifier' 'FAIL' "Terminates with '$actualAll' but '$expectedAll' is required."
        }
    } else {
        Add-Finding $name 'SPF all-qualifier' 'FAIL' "No all-qualifier found; record does not terminate correctly."
    }

    # RFC 7208 caps SPF evaluation at ten DNS-querying mechanisms.
    $lookupPattern = '(?i)(?:^|[\s+\-~?])(?:include:|redirect=|exists:|ptr(?=[\s:]|$)|a(?=[\s:]|$)|mx(?=[\s:]|$))'
    $lookupCount   = ([regex]::Matches($record, $lookupPattern)).Count
    if ($lookupCount -gt 10) {
        Add-Finding $name 'SPF lookup limit' 'FAIL' "$lookupCount DNS-querying mechanisms; RFC 7208 caps this at 10 and receivers will return permerror."
    } elseif ($lookupCount -ge 8) {
        Add-Finding $name 'SPF lookup limit' 'WARN' "$lookupCount DNS-querying mechanisms; approaching the RFC 7208 limit of 10."
    } else {
        Add-Finding $name 'SPF lookup limit' 'PASS' "$lookupCount DNS-querying mechanisms, within the limit of 10."
    }
}

function Test-DkimPosture {
    param([Parameter(Mandatory)]$DomainConfig, [Parameter(Mandatory)][string]$Endpoint)

    $name = $DomainConfig.name
    foreach ($selector in @($DomainConfig.expected_dkim_selectors)) {
        $fqdn    = "$selector._domainkey.$name"
        $records = @(Get-DnsRecord -Name $fqdn -Type 'CNAME' -Endpoint $Endpoint)
        if ($records.Count -eq 0) {
            $records = @(Get-DnsRecord -Name $fqdn -Type 'TXT' -Endpoint $Endpoint)
        }
        if ($records.Count -eq 0) {
            Add-Finding $name "DKIM $selector" 'FAIL' "Selector does not resolve at $fqdn. DKIM signing is not published for this selector."
        } else {
            Add-Finding $name "DKIM $selector" 'PASS' "Resolves: $($records -join '; ')"
        }
    }
}

function Test-DmarcPosture {
    param([Parameter(Mandatory)]$DomainConfig, [Parameter(Mandatory)][string]$Endpoint)

    $name    = $DomainConfig.name
    $fqdn    = "_dmarc.$name"
    $txt     = Get-DnsRecord -Name $fqdn -Type 'TXT' -Endpoint $Endpoint
    $records = @($txt | Where-Object { $_ -match '^v=DMARC1\b' })

    if ($records.Count -eq 0) {
        Add-Finding $name 'DMARC' 'FAIL' "No v=DMARC1 record at $fqdn. The domain is unprotected against spoofing."
        return
    }
    if ($records.Count -gt 1) {
        Add-Finding $name 'DMARC' 'FAIL' "$($records.Count) DMARC records published; receivers ignore the policy entirely when more than one exists."
        return
    }

    $record = $records[0]
    Add-Finding $name 'DMARC' 'PASS' "Record present: $record"

    $rank     = @{ 'none' = 0; 'quarantine' = 1; 'reject' = 2 }
    $expected = ([string]$DomainConfig.expected_dmarc_policy).ToLowerInvariant()

    if (-not $rank.ContainsKey($expected)) {
        Add-Finding $name 'DMARC policy' 'FAIL' "Config declares expected_dmarc_policy '$expected', which is not one of none, quarantine, reject."
        return
    }

    if ($record -match '\bp\s*=\s*(?<policy>none|quarantine|reject)\b') {
        $actual = $Matches['policy'].ToLowerInvariant()
        if ($rank[$actual] -ge $rank[$expected]) {
            Add-Finding $name 'DMARC policy' 'PASS' "p=$actual meets the required minimum of p=$expected."
        } else {
            $extra = if ($actual -eq 'none') { ' p=none is monitor-only: it generates aggregate reports but blocks nothing.' } else { '' }
            Add-Finding $name 'DMARC policy' 'FAIL' "p=$actual is weaker than the required p=$expected.$extra"
        }
    } else {
        Add-Finding $name 'DMARC policy' 'FAIL' 'No valid p= tag found.'
    }

    if ($record -match '\brua\s*=\s*(?<rua>[^;]+)') {
        $ruaAddresses = @($Matches['rua'] -split ',' | ForEach-Object { ($_ -replace '(?i)^\s*mailto:', '').Trim() } | Where-Object { $_ })
        $allowed      = @($DomainConfig.allowed_rua_addresses | ForEach-Object { $_.ToLowerInvariant() })

        foreach ($address in $ruaAddresses) {
            if ($allowed -contains $address.ToLowerInvariant()) {
                Add-Finding $name 'DMARC rua' 'PASS' "Aggregate reports go to an approved mailbox: $address"
            } else {
                Add-Finding $name 'DMARC rua' 'FAIL' "Aggregate reports go to '$address', which is not on the allow-list. Reports for a tenant-owned domain are being delivered outside that tenant."
            }
        }
    } else {
        Add-Finding $name 'DMARC rua' 'WARN' 'No rua= tag. The policy is enforced but nobody receives aggregate reports, so spoofing goes unobserved.'
    }
}

function Compare-CloudflareRecord {
    <#
        Reconcile what Cloudflare holds against what the public resolver returns.
        A mismatch usually means a record was edited in the dashboard but the old
        value is still cached, or the zone is not authoritative for the name.
    #>
    param(
        [Parameter(Mandatory)]$DomainConfig,
        [Parameter(Mandatory)][AllowEmptyCollection()][array]$ZoneRecords,
        [Parameter(Mandatory)][string]$Endpoint
    )

    $name = $DomainConfig.name
    if ($ZoneRecords.Count -eq 0) {
        Add-Finding $name 'Cloudflare zone' 'WARN' 'No zone records retrieved; skipping reconciliation.'
        return
    }

    $zoneSpf = @($ZoneRecords | Where-Object { $_.type -eq 'TXT' -and $_.name -eq $name -and $_.content -match '^v=spf1' })
    $liveSpf = @(Get-DnsRecord -Name $name -Type 'TXT' -Endpoint $Endpoint | Where-Object { $_ -match '^v=spf1' })

    if ($zoneSpf.Count -eq 1 -and $liveSpf.Count -eq 1) {
        if ($zoneSpf[0].content.Trim() -eq $liveSpf[0].Trim()) {
            Add-Finding $name 'Cloudflare SPF drift' 'PASS' 'Zone SPF matches the publicly resolved record.'
        } else {
            Add-Finding $name 'Cloudflare SPF drift' 'WARN' "Zone holds '$($zoneSpf[0].content)' but resolvers return '$($liveSpf[0])'. Likely TTL cache or a non-authoritative zone."
        }
    }

    $zoneDmarc = @($ZoneRecords | Where-Object { $_.type -eq 'TXT' -and $_.name -eq "_dmarc.$name" -and $_.content -match '^v=DMARC1' })
    $liveDmarc = @(Get-DnsRecord -Name "_dmarc.$name" -Type 'TXT' -Endpoint $Endpoint | Where-Object { $_ -match '^v=DMARC1' })

    if ($zoneDmarc.Count -eq 1 -and $liveDmarc.Count -eq 1) {
        if ($zoneDmarc[0].content.Trim() -eq $liveDmarc[0].Trim()) {
            Add-Finding $name 'Cloudflare DMARC drift' 'PASS' 'Zone DMARC matches the publicly resolved record.'
        } else {
            Add-Finding $name 'Cloudflare DMARC drift' 'WARN' "Zone holds '$($zoneDmarc[0].content)' but resolvers return '$($liveDmarc[0])'."
        }
    }

    $proxied = @($ZoneRecords | Where-Object { $_.type -eq 'TXT' -and ($_.PSObject.Properties.Name -contains 'proxied') -and $_.proxied })
    if ($proxied.Count -gt 0) {
        Add-Finding $name 'Cloudflare TXT proxy' 'WARN' "$($proxied.Count) TXT record(s) marked proxied; TXT records must never be proxied."
    }
}

function Get-AuditConfig {
    param([Parameter(Mandatory)][string]$Path)

    if (-not (Test-Path $Path)) {
        $examplePath = $Path -replace '\.yml$', '.example.yml'
        if (Test-Path $examplePath) {
            Copy-Item $examplePath $Path
            Write-Log "Created '$Path' from example - fill in your values before re-running." 'WARN'
        }
        throw "Config file not found: $Path"
    }

    $config = Get-Content -Path $Path -Raw | ConvertFrom-Yaml
    foreach ($required in @('resolver', 'cloudflare', 'domains')) {
        if (-not $config.ContainsKey($required)) {
            throw "Config '$Path' is missing the required '$required' section."
        }
    }
    return $config
}

# === Main ===

Write-Log "Mail-posture audit starting. Log: $script:logFile" 'HEADER'
Import-RequiredModule -Name 'powershell-yaml'

$config      = Get-AuditConfig -Path $ConfigPath
$dohEndpoint = $config.resolver.doh_endpoint
$targets     = @($config.domains)

if ($Domain) {
    $targets = @($targets | Where-Object { $_.name -eq $Domain })
    if ($targets.Count -eq 0) { throw "Domain '$Domain' is not present in '$ConfigPath'." }
}

$apiToken = $null
if (-not $SkipCloudflare) {
    if ($DryRun) {
        Write-Log 'DRY RUN: would resolve the Cloudflare API token and query the zone.' 'WARN'
    } else {
        $apiToken = Resolve-KeyVaultRef -KvUri $config.cloudflare.api_token
        if (-not $apiToken) {
            Write-Log 'Cloudflare token unavailable; continuing with public DNS only.' 'WARN'
        }
    }
}

foreach ($domainConfig in $targets) {
    Write-Log "Auditing $($domainConfig.name) (tenant: $($domainConfig.tenant))" 'HEADER'

    Test-MxPosture    -DomainConfig $domainConfig -Endpoint $dohEndpoint
    Test-SpfPosture   -DomainConfig $domainConfig -Endpoint $dohEndpoint
    Test-DkimPosture  -DomainConfig $domainConfig -Endpoint $dohEndpoint
    Test-DmarcPosture -DomainConfig $domainConfig -Endpoint $dohEndpoint

    if ($apiToken) {
        $zoneRecords = Get-CloudflareZoneRecord -ZoneName $domainConfig.name -ApiToken $apiToken -ApiBaseUrl $config.cloudflare.api_base_url
        Compare-CloudflareRecord -DomainConfig $domainConfig -ZoneRecords $zoneRecords -Endpoint $dohEndpoint
    }
}

Write-Host ''
Write-Host '=== Mail posture summary ===' -ForegroundColor Cyan
$script:findings | Format-Table -AutoSize -Wrap

$failCount = @($script:findings | Where-Object Status -eq 'FAIL').Count
$warnCount = @($script:findings | Where-Object Status -eq 'WARN').Count

Write-Host ''
if ($failCount -gt 0) {
    Write-Host "$failCount failure(s), $warnCount warning(s). Full log: $script:logFile" -ForegroundColor Red
    exit 1
}
if ($warnCount -gt 0) {
    Write-Host "0 failures, $warnCount warning(s). Full log: $script:logFile" -ForegroundColor Yellow
    exit 0
}
Write-Host "All checks passed. Full log: $script:logFile" -ForegroundColor Green
exit 0
