# Repo intent — Hybrid-Solutions-Cloud.github.io

**Public project catalog for Hybrid Solutions Cloud Labs — labs.hybridsolutions.cloud.**

## What this repo is

The source for labs.hybridsolutions.cloud, the public project catalog for the
Hybrid-Solutions-Cloud GitHub organization. A static Next.js export, deployed via
GitHub Actions to GitHub Pages on every `main` change. A Cloudflare Worker
(`worker/index.js`) serves that Pages origin only on `labs.hybridsolutions.cloud`,
preserving incoming paths so existing GitHub project sites remain reachable (e.g.
`labs.hybridsolutions.cloud/homestead-foundry/`, `labs.hybridsolutions.cloud/azure-scout/`).

## What this repo is not

- The main company site at **hybridsolutions.cloud** is a separate property, not
  deployed or configured by this repo — don't confuse the two domains

## How it relates to other repos

- Catalogs and paths to every public project under the org: `homestead-foundry`,
  `azure-scout`, `hybrid-infra-toolkit`, `hybrid-health-monitoring`,
  `azure-monitor-itsm`, `hyperv-surveyor`, `project-marvin`

## Status

Active — the org's public front door.
