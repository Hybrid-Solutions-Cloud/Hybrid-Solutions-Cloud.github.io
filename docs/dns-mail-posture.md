# DNS mail posture — audit runbook

## Why this exists

`hybridsolutions.cloud` is the primary domain of the **`hcs` root tenant**
(`This Is My Demo / hybridsolutions.cloud`, account `kris@hybridsolutions.cloud`,
central vault `kv-hcs-vault-01`). It is a live Microsoft 365 tenant that sends
real mail.

The Cloudflare zone carrying its SPF, DKIM and DMARC records is hand-managed in
the dashboard. No repo in the HCS registry holds it — a search across all 140
registered repos returns no DNS, Cloudflare, or zone repo of any kind. That has
two consequences:

1. **The configuration is not inspectable.** "What did we set up on this domain?"
   cannot be answered from source, only by opening the dashboard.
2. **DNS sits outside the infrastructure standard**, which requires infrastructure
   to be declarative, versioned, and changed through a reviewed pipeline with plan
   output.

`scripts/Invoke-DomainMailAudit.ps1` closes the visibility half of that gap. It
does not manage DNS — it reads the live records, reconciles them against what
Cloudflare holds, and asserts them against a declared expected posture. Codifying
the zone itself is the remaining work; see [Open items](#open-items).

## What DMARC aggregate reports actually are

Mail such as `Report Domain: hybridsolutions.cloud Submitter: wp.pl Report-ID: …`
carrying a small ZIP of XML is a **DMARC aggregate report**, not spam. The `rua=`
tag in the `_dmarc` TXT record is a standing request to every receiving mail
server on the internet: send a daily XML summary of everything claiming to be from
this domain. Reports arriving from many unrelated providers is the protocol
working as designed.

Two things follow, and they are commonly confused:

- DMARC protects **other people** from forged mail claiming to be from the domain.
  It does **not** filter spam arriving in the domain's own inboxes.
- `p=none` still generates the full report volume while blocking nothing. Report
  traffic is therefore not evidence that enforcement is on.

## Running the audit

Requires PowerShell 7+ and a host with outbound access to the DoH resolver and
the Cloudflare API. Per the build-environments standard, prefer WSL (Tier 1) or
`bld-01` (Tier 2).

```powershell
Copy-Item config/mail-posture.example.yml config/mail-posture.yml
# Fill in the REPLACE-WITH values, then:
./scripts/Invoke-DomainMailAudit.ps1
```

| Invocation | Effect |
|---|---|
| `./scripts/Invoke-DomainMailAudit.ps1` | Audit every domain in the config. |
| `-Domain hybridsolutions.cloud` | Audit a single domain. |
| `-SkipCloudflare` | Public DNS only; no API token needed. |
| `-DryRun` | Run every lookup, skip the Cloudflare API calls. |

The script is read-only and never writes a DNS record. It exits `1` if any check
fails, `0` otherwise, so it can gate a pipeline.

## What it checks

| Check | Fails when |
|---|---|
| MX | A sending domain publishes no MX, or publishes a null MX that blackholes inbound mail. |
| SPF present | No `v=spf1` record, or more than one (multiple records are a permerror — receivers ignore SPF entirely). |
| SPF includes | A required mechanism such as `include:spf.protection.outlook.com` is absent, so legitimate mail fails SPF. |
| SPF all-qualifier | The record does not terminate with the required `-all` or `~all`. |
| SPF lookup limit | More than ten DNS-querying mechanisms, exceeding the RFC 7208 cap. |
| DKIM | An expected selector (Exchange Online publishes `selector1` and `selector2`) does not resolve. |
| DMARC present | No `v=DMARC1` record, or more than one. |
| DMARC policy | The published policy is weaker than the declared minimum. `p=none` is monitor-only. |
| DMARC rua | An aggregate-report address is not on the allow-list. |
| Cloudflare drift | The zone's record and the publicly resolved record disagree, or a TXT record is proxied. |

## The rua allow-list check

`allowed_rua_addresses` is the check worth understanding. Aggregate reports for a
tenant-owned domain should be delivered to a mailbox **inside that tenant**, or to
a report processor the tenant controls — for example Cloudflare's built-in DMARC
Management, which provisions its own address and renders the reports as a
dashboard instead of mail.

An `rua=` pointing at a personal mailbox outside the tenant is reported as a
failure. It is not merely noisy: the spoofing telemetry for a production domain
ends up somewhere outside the tenant's control and outside its retention.

## Reducing report volume, correctly

In order of preference:

1. **Cloudflare DMARC Management** — zone → Email → DMARC Management. Repoints
   `rua=` at a Cloudflare-managed address and gives a dashboard. Full visibility,
   quiet inbox.
2. **A dedicated in-tenant mailbox** for `rua=`, fed to a processor.
3. **Dropping the `rua=` tag** — enforcement continues, but spoofing becomes
   unobservable. The audit reports this as a warning, not a pass.

Filtering the reports into a folder addresses the annoyance without addressing
where the data goes, so it is not a substitute for the above.

## Do not do this

Do **not** apply a null MX (`. 0`) plus `v=spf1 -all` to `hybridsolutions.cloud`.
That pattern is correct only for a domain that never sends or receives mail. The
root tenant's primary domain does both, and applying it would blackhole tenant
mail. The audit's `sends_mail` flag exists precisely to keep the two cases apart.

## Open items

- **Codify the zone.** The audit reads state; it does not own it. A
  `cloudflare_record` Terraform configuration (or an equivalent export committed
  and diffed in CI) would bring DNS under the infrastructure standard's
  plan → review → apply model. This belongs in `platform`, not here.
- **Decide the `rua=` destination** for each tenant domain and record it in
  `allowed_rua_addresses`.
- **Confirm enforcement.** Verify the published policy is `p=reject` and not
  `p=none`; report volume alone does not distinguish them.
