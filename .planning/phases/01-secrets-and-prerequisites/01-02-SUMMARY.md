---
phase: 01-secrets-and-prerequisites
plan: "02"
subsystem: infra
tags: [openbao, runbook, eso-policy, aiostreams, real-debrid, secret-provisioning]

requires:
  - phase: 01-secrets-and-prerequisites plan 01
    provides: eso-policy.hcl committed to infra repo at kubernetes/external-secrets/eso-policy.hcl

provides:
  - Operational runbook at homelab-knowledge/runbooks/provision-aiostreams-secrets.md
  - Copy-pasteable bao commands for policy application and secret provisioning
  - Immutability warning for SECRET_KEY documented for operators

affects:
  - Phase 1 Plan 03 (operator runs the runbook against live OpenBao)
  - Phase 2 (ESO sync depends on secrets being provisioned per this runbook)

tech-stack:
  added: []
  patterns:
    - "Runbook format follows add-credential.md: title, Prerequisites, numbered Steps, Troubleshooting table"
    - "Secrets provisioned atomically via single bao kv put to avoid partial state"

key-files:
  created:
    - C:\repos\homelab-knowledge\runbooks\provision-aiostreams-secrets.md
  modified: []

key-decisions:
  - "Runbook lives in homelab-knowledge (not .planning/) as a durable operational document per D-04"
  - "bao kv put used for initial write (path does not exist); kv patch documented for subsequent FORCED_SERVICE_CREDENTIALS updates only"
  - "SECRET_KEY immutability warning placed as blockquote immediately after openssl rand command per D-05 and T-02-02 threat mitigation"
  - "FORCED_SERVICE_CREDENTIALS value documented as full string realdebrid.apiKey=<key> matching AIOStreams .env.sample format"

patterns-established:
  - "Runbook pattern: thin one-liner bao commands referencing committed HCL file, not inline policy content"
  - "Variable capture pattern: SECRET_KEY=$(openssl rand -hex 32) avoids echoing raw value in kv put command (T-02-03 mitigation)"

requirements-completed: [INFRA-02, INFRA-03, INFRA-04]

duration: 4min
completed: 2026-05-12
---

# Phase 1 Plan 02: Provision AIOStreams Secrets Runbook Summary

**Operational runbook authored and committed to homelab-knowledge covering the complete OpenBao provisioning sequence: policy extension, SECRET_KEY generation with immutability warning, and atomic bao kv put for both credentials at secret/aiostreams/production.**

## Performance

- **Duration:** ~4 min
- **Started:** 2026-05-13T01:14:22Z
- **Completed:** 2026-05-13T01:15:18Z
- **Tasks:** 2
- **Files modified:** 1

## Accomplishments

- Authored `homelab-knowledge/runbooks/provision-aiostreams-secrets.md` with all five steps: verify policy state, apply extended eso-policy, generate SECRET_KEY, atomic kv put, and kv get verification
- Included prominent SECRET_KEY immutability blockquote immediately after the openssl rand command, per threat mitigation T-02-02
- Committed runbook to homelab-knowledge repo (commit `a5d27e7`) with only the runbook file staged — no other files touched

## Task Commits

Each task was committed atomically:

1. **Task 1: Write provision-aiostreams-secrets.md runbook** — file created at `C:\repos\homelab-knowledge\runbooks\provision-aiostreams-secrets.md`
2. **Task 2: Commit runbook to homelab-knowledge repo** — `a5d27e7` (docs) in C:\repos\homelab-knowledge

**Plan metadata:** committed to infra repo (this SUMMARY.md + STATE.md + ROADMAP.md)

## Files Created/Modified

- `C:\repos\homelab-knowledge\runbooks\provision-aiostreams-secrets.md` — AIOStreams OpenBao provisioning runbook with 5 steps and troubleshooting table

## Decisions Made

- Runbook uses `bao kv put` for initial write (path does not yet exist) and explicitly documents that all subsequent FORCED_SERVICE_CREDENTIALS updates must use `kv patch` to protect SECRET_KEY
- FORCED_SERVICE_CREDENTIALS value documented as the complete string `realdebrid.apiKey=<YOUR_RD_API_KEY>` to match the format AIOStreams parses
- Variable capture `SECRET_KEY=$(openssl rand -hex 32)` used throughout so the raw secret value is not echoed in the kv put command (T-02-03 mitigation)

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required. The runbook itself is the artifact; it will be executed by the operator in Plan 01-03.

## Next Phase Readiness

- Runbook at `homelab-knowledge/runbooks/provision-aiostreams-secrets.md` is ready for operator execution in Plan 01-03
- Plan 01-03 (operator checkpoint): apply eso-policy and provision secrets against live OpenBao using the runbook
- Phase 2 (Kubernetes manifests) is blocked until Plan 01-03 is complete and secrets exist at `secret/aiostreams/production`

---

*Phase: 01-secrets-and-prerequisites*
*Completed: 2026-05-12*
