# BCOS GitHub Action

**Beacon Certified Open Source** — Verify repository trust score and certify open source quality on RustChain.

## Usage

```yaml
name: BCOS Certification
on:
  pull_request:
    types: [opened, synchronize, reopened]
  push:
    branches: [main]

jobs:
  bcos:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Run BCOS Certification
        uses: Scottcjn/bcos-action@v1
        with:
          tier: "L1"           # L0, L1, or L2
          reviewer: ""          # Required for L2
          node-url: "https://50.28.86.131"
```

## Inputs

| Input | Description | Required | Default |
|-------|-------------|----------|---------|
| `tier` | Certification tier: `L0`, `L1`, or `L2` | No | `L1` |
| `reviewer` | Human reviewer name (required for L2) | No | `""` |
| `node-url` | RustChain node URL for attestation anchoring | No | `https://50.28.86.131` |
| `github-token` | GitHub token for posting PR comments | No | `${{ github.token }}` |
| `repo-path` | Path to repository to scan | No | `${{ github.workspace }}` |

## Outputs

| Output | Description |
|--------|-------------|
| `trust_score` | BCOS trust score (0-100) |
| `cert_id` | BCOS certificate ID (e.g. `BCOS-a1b2c3d4`) |
| `tier_met` | Whether the claimed tier was met (`true`/`false`) |
| `score_breakdown` | URL-encoded JSON breakdown of scores |

## Tiers

| Tier | Threshold | Requirements |
|------|-----------|--------------|
| **L0** | ≥ 40 | Automated checks only (lint, tests, SPDX, SBOM) |
| **L1** | ≥ 60 | L0 + 2 independent agent reviews |
| **L2** | ≥ 80 | L1 + 1 human approval + Ed25519 signature |

## What It Checks

BCOS v2 Engine evaluates 7 components (100 pts total):

1. **License Compliance (20 pts)** — SPDX headers + OSI-compatible dependencies
2. **Vulnerability Scan (25 pts)** — pip-audit / osv-scanner for CVEs
3. **Static Analysis (20 pts)** — Semgrep for code quality issues
4. **SBOM Completeness (10 pts)** — CycloneDX SBOM generation
5. **Dependency Freshness (5 pts)** — Up-to-date dependencies
6. **Test Evidence (10 pts)** — Test suite presence + CI configs
7. **Review Attestation (10 pts)** — Tier-based review requirements

## PR Comment

On pull requests, the action posts a comment with:
- Badge with cert ID and pass/fail status
- Trust score and tier result
- Score breakdown table
- Link to full verification

## Attestation Anchoring

On merge to `main`, the attestation is anchored to the RustChain node, creating an immutable trust record tied to the commit SHA.

## License

MIT — Free & Open Source. https://rustchain.org/bcos

---

*Built by Atlas (Bounty Hunter) 🤖💰*
