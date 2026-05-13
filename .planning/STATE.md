---
gsd_state_version: 1.0
milestone: v1.0
milestone_name: milestone
status: executing
last_updated: "2026-05-13T02:56:17.571Z"
progress:
  total_phases: 3
  completed_phases: 1
  total_plans: 6
  completed_plans: 3
  percent: 50
---

# Project State: AIOStreams Stremio Filtering Layer

**Project:** AIOStreams: Stremio Filtering Layer  
**Initialized:** 2026-05-11  
**Status:** Executing Phase 02

---

## Project Reference

**Core Value:** Click a result in Stremio and it plays — no "infringing file" dead links, no provider migration required.

**Current Focus:** Phase 02 — kubernetes-manifests

**Key Constraint:** OpenBao policy must be extended to `secret/data/aiostreams/*` before Phase 2 ESO sync can succeed.

---

## Current Position

Phase: 02 (kubernetes-manifests) — EXECUTING
Plan: 1 of 3
**Milestone:** 1.0 (AIOStreams v2.29.5 self-hosted on k3s)

**Phase:** 2 — Kubernetes Manifests (not started)

**Plan:** Phase 1 complete (3/3 plans). Phase 2 plans TBD.

**Progress:** Phase 1 complete

**Visual Progress:**

```
Phase 1: [████████████████████] 3/3 plans ✓
Phase 2: [                    ] 0/? plans  
Phase 3: [                    ] 0/4 plans
```

---

## Roadmap Summary

| Phase | Goal | Blocked By | Status |
|-------|------|-----------|--------|
| 1 | Secure credential infrastructure in OpenBao and document provisioning runbook | Nothing | ✅ Complete (2026-05-13) |
| 2 | AIOStreams pod running and responding to health checks from any LAN device | Phase 1 (policy + secrets) | Ready to plan |
| 3 | Filter validated in Stremio and architectural decision recorded | Phase 2 (pod must be running) | Not started |

---

## Performance Metrics

**Coverage:**

- v1 Requirements: 13/13 mapped ✓
- Phases: 3
- Granularity: Standard (3 phases)

**Dependencies:**

- Phase 2 depends on Phase 1 (critical path: ESO policy and OpenBao secrets)
- Phase 3 depends on Phase 2 (must have running pod to configure filters)

---

## Accumulated Context

### Decisions Made

1. **Phase structure (user-decided):** Horizontal Layers pattern — Secrets → Kubernetes → Configuration. This aligns with infrastructure deployment order and risk mitigation (no pod can start without secrets).

2. **Requirement coverage:** All 13 v1 requirements mapped. No orphans, no duplicates.

3. **Success criteria basis:** Observable user/operator behavior, not implementation tasks:
   - Phase 1: Runbook exists, secrets stored, policy updated
   - Phase 2: Pod healthy, `/api/v1/status` responds from LAN, ArgoCD synced
   - Phase 3: Filter blocks WEB-DL/YTS/AMZN in Stremio, ADR recorded

4. **ESO policy capability scope (01-01):** Use `["read"]` only (not `["read", "list"]`) for aiostreams/* — matches homelab/ci convention and principle of least privilege. ESO fetches a specific path, not a directory listing.

5. **Policy HCL co-location (01-01):** Store HCL policy file alongside ClusterSecretStore in `kubernetes/external-secrets/` for discoverability and ESO config co-location.

6. **Runbook location (01-02):** Runbook lives in homelab-knowledge (not .planning/) as a durable operational document per D-04. Follows add-credential.md format.

7. **SECRET_KEY immutability warning placement (01-02):** Immutability blockquote placed immediately after openssl rand command, before bao kv put — per D-05 and T-02-02 threat mitigation.

8. **FORCED_SERVICE_CREDENTIALS format (01-02):** Full string `realdebrid.apiKey=<key>` documented (not just the key value) to match AIOStreams .env.sample format.

### Technical Constraints

- **eso-policy scope:** Existing role scoped to `secret/data/homelab/ci` — Phase 1 must extend to `secret/data/aiostreams/*`
- **SECRET_KEY immutability:** 64-char hex, generated via `openssl rand -hex 32`, never rotated (per ADR constraint)
- **FORCED_SERVICE_CREDENTIALS format:** `realdebrid.apiKey=<value>` must match AIOStreams `.env.sample`
- **Network isolation:** MetalLB LoadBalancer sufficient; no external exposure
- **Pod readiness:** Both liveness and readiness probes on `GET /api/v1/status` required

### Open Questions

None at roadmap stage. Planning Phase 1 will detail exact `bao` commands and runbook.

### Blockers

None. Phase 1 can start immediately.

---

## Session Continuity

**Last session:** 2026-05-13T02:31:30.110Z
**Context loss risk:** Low — ROADMAP.md, REQUIREMENTS.md, STATE.md, and phase plans capture full project state

**Phase 1 live state:**

- `eso-policy` extended to cover `secret/data/aiostreams/*` (INFRA-01 ✓)
- `secret/aiostreams/production` provisioned — `SECRET_KEY` (64-char hex, immutable) + `FORCED_SERVICE_CREDENTIALS` (INFRA-02, INFRA-03 ✓)

**Next action:** `/gsd-plan-phase 2` — Kubernetes Manifests (namespace, ExternalSecret, Deployment, PVC, Service, ArgoCD App)

---

*State initialized: 2026-05-11*
