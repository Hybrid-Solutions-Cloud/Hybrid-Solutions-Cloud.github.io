# Hybrid Solutions Cloud Labs

The source for [labs.hybridsolutions.cloud](https://labs.hybridsolutions.cloud), the public project catalog for the [Hybrid-Solutions-Cloud](https://github.com/Hybrid-Solutions-Cloud) GitHub organization.

The main company site at [hybridsolutions.cloud](https://hybridsolutions.cloud) is a separate property and is not deployed or configured by this repository.

## Local development

Requires Node.js 22 or newer.

```powershell
npm ci
npm run dev
```

The production site is a static Next.js export:

```powershell
npm test
```

## Publishing

The repository is designed to be published as the `Hybrid-Solutions-Cloud/Hybrid-Solutions-Cloud.github.io` organization site. A GitHub Actions workflow builds the static export and deploys it to GitHub Pages whenever `main` changes.

GitHub applies an organization site's custom domain to that organization's project sites. With `labs.hybridsolutions.cloud` configured on the organization site, existing project sites remain available at paths such as:

- `https://labs.hybridsolutions.cloud/homestead-foundry/`
- `https://labs.hybridsolutions.cloud/azure-scout/`

The only intended DNS change is a DNS-only `CNAME` for `labs.hybridsolutions.cloud` pointing to `hybrid-solutions-cloud.github.io`. Do not modify the apex domain or unrelated records.
