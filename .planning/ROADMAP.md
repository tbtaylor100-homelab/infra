# AIOStreams Stremio Filtering Layer — Roadmap

**Project:** AIOStreams: Stremio Filtering Layer  
**Defined:** 2026-05-11  
**Granularity:** Standard (3 phases)  
**Model:** Horizontal Layers (Secrets → Kubernetes → Configuration)

---

## Phases

- [ ] **Phase 1: Secrets & Prerequisites** — Extend OpenBao policy, generate SECRET_KEY, store RD credentials, document runbook
- [ ] **Phase 2: Kubernetes Manifests** — Deploy namespace, ExternalSecret, Deployment, Service, PVC, and ArgoCD Application
- [ ] **Phase 3: Configuration & Documentation** — Post-deploy UI setup, filter validation procedure, architectural decision record

---

## Phase Details

### Phase 1: Secrets & Prerequisites

**Goal:** Secure credential infrastructure in place so Kubernetes sync can retrieve secrets without race conditions.

**Depends on:** Nothing (foundation)

**Requirements:** INFRA-01, INFRA-02, INFRA-03, INFRA-04

**Success Criteria** (what must be TRUE):

1. `bao policy show eso-policy` output includes `path "secret/data/aiostreams/*"` with read permissions
2. `bao kv get secret/aiostreams/production` returns a non-empty secret with `SECRET_KEY` (64-char hex) and `FORCED_SERVICE_CREDENTIALS` fields
3. Runbook at `homelab-knowledge/runbooks/provision-aiostreams-secrets.md` documents exact `bao kv put` and `openssl rand -hex 32` commands
4. OpenBao audit log confirms policy update and secret creation within same session

**Plans:** 3 plans

Plans:
- [x] 01-01-PLAN.md — Author and commit eso-policy.hcl with both policy paths (infra repo)
- [x] 01-02-PLAN.md — Author and commit AIOStreams provisioning runbook (homelab-knowledge repo)
- [ ] 01-03-PLAN.md — Apply eso-policy and provision secrets against live OpenBao (operator checkpoint)

---

### Phase 2: Kubernetes Manifests

**Goal:** AIOStreams pod running and responding to health checks from any LAN device.

**Depends on:** Phase 1 (OpenBao policy and secrets must exist before ESO can sync)

**Requirements:** K8S-01, K8S-02, K8S-03, K8S-04, K8S-05, K8S-06

**Success Criteria** (what must be TRUE):

1. `kubectl get namespace aiostreams` returns status Active
2. `kubectl get deployment -n aiostreams aiostreams` shows 1/1 Ready replicas with no restarts
3. `curl -s http://<metallb-ip>:3000/api/v1/status` from a LAN device (not control plane) returns HTTP 200 with valid JSON
4. `ArgoCD Applications` UI shows `argocd/apps/aiostreams.yaml` synced and healthy (no OutOfSync conditions)
5. PVC `aiostreams-sqlite` is Bound with 10Gi available and mounted at `/app/data` in the pod

**Plans:** TBD

---

### Phase 3: Configuration & Documentation

**Goal:** Filter validated and architectural decision recorded so operators can replicate and justify the deployment.

**Depends on:** Phase 2 (AIOStreams must be running to configure filters and verify results)

**Requirements:** CONF-01, CONF-02, DOC-01

**Success Criteria** (what must be TRUE):

1. Stremio client added Torrentio addon source pointing to `http://<metallb-ip>:3000` as a filtering proxy
2. Real-Debrid credentials configured in AIOStreams UI and FORCED_SERVICE_CREDENTIALS env var is active
3. Test search in Stremio for known WEB-DL/YTS/AMZN-tagged release does not display filtered-out streams; `.planning/runbooks/validate-filter.md` documents the test procedure
4. `homelab-knowledge` ADR records the decision, problem statement (RD May 2026 blocks), alternatives (Comet, ElfHosted), key constraints (SECRET_KEY immutability, intranet-only), and rationale

**Plans:** TBD

**UI hint**: yes

---

## Progress Table

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Secrets & Prerequisites | 2/3 | In progress | — |
| 2. Kubernetes Manifests | 0/5 | Not started | — |
| 3. Configuration & Documentation | 0/4 | Not started | — |

---

## Coverage Summary

**v1 Requirements:** 13 total

| Requirement | Phase | Mapped |
|-------------|-------|--------|
| INFRA-01 | 1 | ✓ |
| INFRA-02 | 1 | ✓ |
| INFRA-03 | 1 | ✓ |
| INFRA-04 | 1 | ✓ |
| K8S-01 | 2 | ✓ |
| K8S-02 | 2 | ✓ |
| K8S-03 | 2 | ✓ |
| K8S-04 | 2 | ✓ |
| K8S-05 | 2 | ✓ |
| K8S-06 | 2 | ✓ |
| CONF-01 | 3 | ✓ |
| CONF-02 | 3 | ✓ |
| DOC-01 | 3 | ✓ |

**Coverage:** 13/13 requirements mapped ✓

---

*Roadmap created: 2026-05-11*
*Phase 1 planned: 2026-05-12*
