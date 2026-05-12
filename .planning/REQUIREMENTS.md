# Requirements: AIOStreams Stremio Filtering Layer

**Defined:** 2026-05-11
**Core Value:** Click a result in Stremio and it plays — no "infringing file" dead links, no provider migration required.

## v1 Requirements

### Secrets & Infrastructure

- [ ] **INFRA-01**: OpenBao `eso-policy` is extended to grant read access to `secret/data/aiostreams/*`
- [ ] **INFRA-02**: AIOStreams `SECRET_KEY` (64-char hex) is generated and stored immutably in OpenBao at `secret/aiostreams/production`
- [ ] **INFRA-03**: Real-Debrid API key is stored in OpenBao at `secret/aiostreams/production` as `FORCED_SERVICE_CREDENTIALS=realdebrid.apiKey=<key>`
- [ ] **INFRA-04**: Secret provisioning runbook documents the exact `bao kv put` commands, policy HCL, and `openssl rand -hex 32` generation step

### Kubernetes Manifests

- [ ] **K8S-01**: Namespace `aiostreams` exists in the cluster
- [ ] **K8S-02**: ArgoCD `Application` CR at `argocd/apps/aiostreams.yaml` watches `kubernetes/aiostreams/` and syncs automatically with prune and self-heal
- [ ] **K8S-03**: `Deployment` runs `ghcr.io/viren070/aiostreams:v2.29.5` with liveness and readiness probes on `GET /api/v1/status`, resource limits (100m/500m CPU, 128Mi/256Mi RAM), and correct env vars (`BASE_URL`, `PORT`, `REGEX_FILTER_ACCESS=all`, `WHITELISTED_REGEX_PATTERNS`)
- [ ] **K8S-04**: `Service` of type `LoadBalancer` exposes AIOStreams on port 3000 via MetalLB, reachable from all intranet devices
- [ ] **K8S-05**: `PersistentVolumeClaim` of 10Gi on `local-path` storage class is mounted at `/app/data` for SQLite persistence across pod restarts
- [ ] **K8S-06**: `ExternalSecret` pulls `SECRET_KEY` and `FORCED_SERVICE_CREDENTIALS` from `ClusterSecretStore/openbao` at `secret/aiostreams/production` and writes them as a native k8s `Secret`

### Configuration & Validation

- [ ] **CONF-01**: AIOStreams UI post-deploy runbook documents adding RD credentials, Torrentio manifest URL, and activating the regex exclusion filter
- [ ] **CONF-02**: Filter validation procedure documents how to confirm WEB-DL, YTS, and AMZN-tagged streams are excluded before surfacing in Stremio

### Documentation

- [ ] **DOC-01**: ADR in `homelab-knowledge` records the decision to deploy AIOStreams, the problem it solves (RD May 2026 blocks), alternatives considered, and key constraints (SECRET_KEY immutability, intranet-only exposure)

## v2 Requirements

### Platform Improvements

- **PLAT-01**: Local DNS hostname (`aiostreams.lan` or similar) resolves to AIOStreams — deferred to platform-wide URL migration initiative
- **PLAT-02**: Traefik IngressRoute replaces direct MetalLB exposure once hostname infrastructure is in place
- **PLAT-03**: PVC backup strategy (Proxmox snapshots or Velero) protects SQLite data — deferred to broader homelab backup initiative

### Resilience

- **RES-01**: Quarterly review process established for updating the RD block regex pattern as Real-Debrid's filter list evolves
- **RES-02**: PostgreSQL backend replaces SQLite if multi-replica or higher-reliability deployment is needed

## Out of Scope

| Feature | Reason |
|---------|--------|
| Switching debrid providers (TorBox, Usenet) | RD remains viable with filtering; provider migration is a separate decision |
| External (internet) exposure | Stremio is LAN-only; no reason to expose AIOStreams publicly |
| Multi-replica / HA deployment | Single homelab node; SQLite concurrency adequate for single user |
| ElfHosted hosted AIOStreams | Self-hosted on k3s preserves the RD cloud buffer and existing infra investment |
| Secondary addon sources (Comet, MediaFusion) | Torrentio + RD is sufficient for v1; expand in v2 once baseline is stable |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| INFRA-01 | 1 | Pending |
| INFRA-02 | 1 | Pending |
| INFRA-03 | 1 | Pending |
| INFRA-04 | 1 | Pending |
| K8S-01 | 2 | Pending |
| K8S-02 | 2 | Pending |
| K8S-03 | 2 | Pending |
| K8S-04 | 2 | Pending |
| K8S-05 | 2 | Pending |
| K8S-06 | 2 | Pending |
| CONF-01 | 3 | Pending |
| CONF-02 | 3 | Pending |
| DOC-01 | 3 | Pending |

**Coverage:**
- v1 requirements: 13 total
- Mapped to phases: 13 ✓
- Unmapped: 0 ✓

---

*Requirements defined: 2026-05-11*
*Traceability updated: 2026-05-11 after roadmap creation*
