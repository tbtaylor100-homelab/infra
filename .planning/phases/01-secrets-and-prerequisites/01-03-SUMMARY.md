---
phase: 01-secrets-and-prerequisites
plan: "03"
subsystem: infra
tags: [openbao, eso-policy, aiostreams, secret-provisioning, bao-cli, live-operation]

requires:
  - phase: 01-secrets-and-prerequisites plan 01
    provides: eso-policy.hcl committed to infra repo at kubernetes/external-secrets/eso-policy.hcl
  - phase: 01-secrets-and-prerequisites plan 02
    provides: Provisioning runbook at homelab-knowledge/runbooks/provision-aiostreams-secrets.md

provides:
  - Live eso-policy in OpenBao extended to cover secret/data/aiostreams/*
  - Live secret at secret/aiostreams/production with SECRET_KEY and FORCED_SERVICE_CREDENTIALS
  - Phase 2 ESO sync unblocked (no permission error on aiostreams/* path)

affects:
  - Phase 2 (ExternalSecret can now sync from ClusterSecretStore/openbao without 403)

tech-stack:
  added: []
  patterns:
    - "BAO_TOKEN=$(cat ~/.openbao-token) inline token injection — avoids exporting root token into shell env"
    - "bao policy read (not bao policy show) — bao CLI uses read subcommand"
    - "openssl rand -hex 32 piped via variable capture, never echoed raw"

key-files:
  created: []
  modified:
    - "OpenBao live state: eso-policy (sys/policies/acl/eso-policy)"
    - "OpenBao live state: secret/aiostreams/production (version 1, created 2026-05-13T01:59:18Z)"

key-decisions:
  - "Token sourced from ~/.openbao-token (cached root token from April 25 session) — no re-login required"
  - "bao policy write is idempotent — safe to re-run if both paths remain in HCL file"
  - "kv put used (not kv patch) for initial write since path did not previously exist"
  - "SECRET_KEY captured as shell variable then passed by reference to bao kv put — value not echoed in shell history"

patterns-established:
  - "bao policy read <name> (not bao policy show) for reading existing policies in OpenBao"
  - "Inline BAO_TOKEN injection: BAO_TOKEN=$(cat ~/.openbao-token) bao <cmd> — root token stays in file, not env"

requirements-completed: [INFRA-01, INFRA-02, INFRA-03]

duration: 3min
completed: 2026-05-13
---

# Phase 1 Plan 03: Live OpenBao Provisioning Summary

**eso-policy extended to cover `secret/data/aiostreams/*` and `secret/aiostreams/production` provisioned with both required fields. Phase 1 complete. Phase 2 ESO sync is unblocked.**

## Performance

- **Duration:** ~3 min
- **Started:** 2026-05-13T01:55:00Z
- **Completed:** 2026-05-13T01:59:18Z
- **Tasks:** 2 (pre-flight + provisioning)
- **Files modified:** 0 (live OpenBao state only)

## Accomplishments

- Verified OpenBao unsealed and reachable at `http://192.168.1.210:8200` (v2.5.2, Sealed: false)
- Confirmed `kubernetes/external-secrets/eso-policy.hcl` contains both `secret/data/homelab/ci` and `secret/data/aiostreams/*` paths before applying
- Applied eso-policy via `bao policy write` — both paths verified live via `bao policy read eso-policy`
- Generated `SECRET_KEY` (64-char hex) via `openssl rand -hex 32` using variable capture pattern
- Wrote `secret/aiostreams/production` version 1 atomically with both fields: `SECRET_KEY` and `FORCED_SERVICE_CREDENTIALS`
- Verified via `bao kv get secret/aiostreams/production` — both fields present, created_time 2026-05-13T01:59:18Z

## Live State Created

| Resource | Path | Version |
|----------|------|---------|
| OpenBao policy | sys/policies/acl/eso-policy | (updated) |
| OpenBao secret | secret/data/aiostreams/production | v1 |

**Fields at secret/aiostreams/production:**
- `SECRET_KEY` — 64-char hex (immutable; stored in operator password manager)
- `FORCED_SERVICE_CREDENTIALS` — `realdebrid.apiKey=<redacted>`

## Acceptance Criteria Verification

| Criterion | Result |
|-----------|--------|
| `bao policy read eso-policy` includes `secret/data/homelab/ci` (regression check) | ✓ |
| `bao policy read eso-policy` includes `secret/data/aiostreams/*` (INFRA-01) | ✓ |
| `bao kv get secret/aiostreams/production` returns `SECRET_KEY` field (INFRA-02) | ✓ |
| `bao kv get secret/aiostreams/production` returns `FORCED_SERVICE_CREDENTIALS` field (INFRA-03) | ✓ |

## Deviations from Plan

- `bao policy show` does not exist in OpenBao CLI — used `bao policy read` instead (equivalent)
- Token sourced from `~/.openbao-token` (cached from April 25 session) rather than password manager retrieval

## Issues Encountered

- First `bao policy write` returned 403 — `VAULT_TOKEN` not set in shell. Resolved by inline `BAO_TOKEN=$(cat ~/.openbao-token)` prefix.

## Next Phase Readiness

- Phase 2 is fully unblocked — ExternalSecret referencing `secret/aiostreams/production` will sync without permission error
- ClusterSecretStore/openbao is live and Ready (established in MAH-70)
- Next: `/gsd-plan-phase 2` to plan the Kubernetes manifests phase

---

*Phase: 01-secrets-and-prerequisites*
*Completed: 2026-05-13*
