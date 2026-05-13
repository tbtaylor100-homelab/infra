---
phase: 01-secrets-and-prerequisites
plan: "01"
subsystem: infra
tags: [openbao, external-secrets, hcl, kv-v2, eso-policy]

# Dependency graph
requires: []
provides:
  - "kubernetes/external-secrets/eso-policy.hcl committed to infra repo"
  - "Both secret/data/homelab/ci and secret/data/aiostreams/* read paths documented in HCL"
affects:
  - "01-03 (plan that applies the policy to live OpenBao via bao policy write)"
  - "Phase 2 (ExternalSecret manifests depend on eso-policy covering aiostreams/* path)"

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "HCL policy files stored alongside ESO manifests in kubernetes/external-secrets/"
    - "bao policy write is a full replacement — both paths must always be present in the same file"

key-files:
  created:
    - kubernetes/external-secrets/eso-policy.hcl
  modified: []

key-decisions:
  - "Used ['read'] only (not ['read', 'list']) — matches homelab/ci convention and principle of least privilege; ESO fetches specific path, not a directory listing"
  - "Stored HCL policy file alongside ESO ClusterSecretStore in kubernetes/external-secrets/ for co-location of related ESO config"
  - "Included apply command in header comment to prevent accidental partial overwrites when policy is updated in future"

patterns-established:
  - "Policy as code: OpenBao HCL policy files committed to infra repo and applied manually via bao policy write"

requirements-completed:
  - INFRA-01

# Metrics
duration: 2min
completed: 2026-05-12
---

# Phase 1 Plan 01: Author ESO Policy HCL Summary

**OpenBao eso-policy.hcl extended with secret/data/aiostreams/* read access alongside preserved secret/data/homelab/ci path, committed to infra repo**

## Performance

- **Duration:** 2 min
- **Started:** 2026-05-13T01:11:40Z
- **Completed:** 2026-05-13T01:12:13Z
- **Tasks:** 2
- **Files modified:** 1

## Accomplishments
- Created `kubernetes/external-secrets/eso-policy.hcl` with both required policy paths
- Preserved existing `secret/data/homelab/ci` read access (T-01-03 threat mitigated)
- Added new `secret/data/aiostreams/*` read access required for Phase 2 ESO sync (INFRA-01)
- Header comment documents exact `bao policy write` apply command to prevent future partial overwrites

## Task Commits

Each task was committed atomically:

1. **Task 1 + Task 2: Write and commit eso-policy.hcl** - `dd23956` (feat)

**Plan metadata:** (docs commit follows)

## Files Created/Modified
- `kubernetes/external-secrets/eso-policy.hcl` - OpenBao policy HCL granting ESO read access to both homelab/ci and aiostreams/* KV v2 paths

## Decisions Made
- Used `["read"]` only (not `["read", "list"]`) — matches the existing homelab/ci convention and principle of least privilege. ESO fetches a specific path (`secret/aiostreams/production`), not a directory listing.
- Policy file co-located with `cluster-secret-store.yaml` in `kubernetes/external-secrets/` for discoverability.
- Header comment includes the exact `bao policy write` command so future operators applying the policy know to include both paths (guarding against T-01-03: tampering via partial overwrite).

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None.

## User Setup Required
None - no external service configuration required. Policy is authored but not yet applied (Plan 01-03 applies it to live OpenBao).

## Next Phase Readiness
- `eso-policy.hcl` is ready for Plan 01-03 to apply via `bao policy write`
- No blockers for Plan 01-02 (runbook authoring) — that plan is parallel and independent
- Phase 2 ExternalSecret manifests are blocked until Plan 01-03 applies the policy to live OpenBao

## Threat Flags

No new threat surface introduced. Policy file contains no credential values — only path globs and capabilities (T-01-02: safe to commit, accepted).

---
*Phase: 01-secrets-and-prerequisites*
*Completed: 2026-05-12*

## Self-Check: PASSED
- `kubernetes/external-secrets/eso-policy.hcl` — FOUND
- Commit `dd23956` — FOUND (feat(external-secrets): add eso-policy.hcl with aiostreams/* read access)
- Exactly 1 file in commit — CONFIRMED (git show HEAD --name-only shows only eso-policy.hcl)
- Both grep patterns match — CONFIRMED
