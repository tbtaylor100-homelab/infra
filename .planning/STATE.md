# Project State: AIOStreams Stremio Filtering Layer

**Project:** AIOStreams: Stremio Filtering Layer  
**Initialized:** 2026-05-11  
**Status:** Roadmap complete, planning Phase 1

---

## Project Reference

**Core Value:** Click a result in Stremio and it plays — no "infringing file" dead links, no provider migration required.

**Current Focus:** Secure credential infrastructure (Phase 1)

**Key Constraint:** OpenBao policy must be extended to `secret/data/aiostreams/*` before Phase 2 ESO sync can succeed.

---

## Current Position

**Milestone:** 1.0 (AIOStreams v2.29.5 self-hosted on k3s)

**Phase:** 1 — Secrets & Prerequisites (not started)

**Plan:** — (awaiting planning)

**Progress:** Phase 0/3 complete

**Visual Progress:**
```
Phase 1: [                    ] 0/3 plans
Phase 2: [                    ] 0/5 plans  
Phase 3: [                    ] 0/4 plans
```

---

## Roadmap Summary

| Phase | Goal | Blocked By | Status |
|-------|------|-----------|--------|
| 1 | Secure credential infrastructure in OpenBao and document provisioning runbook | Nothing | Not started |
| 2 | AIOStreams pod running and responding to health checks from any LAN device | Phase 1 (policy + secrets) | Not started |
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

**Last session:** Roadmap creation (2026-05-11)  
**Context loss risk:** Low — ROADMAP.md, REQUIREMENTS.md, and this STATE.md capture full project state

**Next action:** `/gsd-plan-phase 1` to decompose Phase 1 into executable plans

---

*State initialized: 2026-05-11*
