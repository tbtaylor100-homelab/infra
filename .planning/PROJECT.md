# AIOStreams: Stremio Filtering Layer

## What This Is

A self-hosted deployment of AIOStreams on the homelab k3s cluster, acting as a filtering proxy between Stremio clients and Torrentio/Real-Debrid. It strips stream results that RD's "infringing file" filter would reject before they surface in the Stremio UI, restoring seamless playback without changing debrid provider. Delivered as ArgoCD-managed Kubernetes manifests with full secrets integration via ESO + OpenBao.

## Core Value

Click a result in Stremio and it plays — no "infringing file" dead links, no provider migration required.

## Requirements

### Validated

- [x] AIOStreams deployed as a k8s workload managed by ArgoCD, matching existing infra conventions — *Validated in Phase 2*
- [x] Real-Debrid API key stored in OpenBao at `secret/aiostreams/production`, synced to k8s via ESO ExternalSecret — *Validated in Phase 2*
- [x] Regex filter pre-configured via `WHITELISTED_REGEX_PATTERNS` to exclude known RD-blocked release tags — *Validated in Phase 2*
- [x] `REGEX_FILTER_ACCESS=all` set so the filter is available without per-user trust configuration — *Validated in Phase 2*
- [x] Service exposed on the intranet via MetalLB LoadBalancer (no external access) — *Validated in Phase 2*
- [x] OpenBao eso-policy extended to cover `secret/data/aiostreams/*` — *Validated in Phase 1*

### Active

- [ ] Post-deploy UI configuration documented as a runbook (add Torrentio source, configure RD credentials, activate filter)
- [ ] Architectural decision documented in homelab-knowledge as an ADR

### Out of Scope

- Local DNS / hostname resolution — deferred to a future platform-wide URL migration initiative
- Switching debrid providers (TorBox, Usenet) — RD remains the primary provider; this project keeps it viable
- Multi-replica or HA deployment — single homelab instance is sufficient
- AIOStreams PostgreSQL backend — SQLite on a PVC is adequate for a single-user instance
- Exposing AIOStreams externally (internet) — intranet-only by design

## Context

**The triggering problem:** Real-Debrid introduced server-side filename filters in May 2026, blocking streams tagged with common release group and source labels (WEB-DL, AMZN, DSNP, YTS, RARBG, EZTV, etc.). These appear in Stremio as unplayable "infringing file" errors, cluttering results and preventing working streams from surfacing. ElfHosted applied a bandaid regex filter on their hosted addons; this project replicates that approach locally.

**Infrastructure context:** The homelab runs a single-node k3s cluster (Proxmox VM), managed via ArgoCD pointing at `http://forgejo.local:3000/root/infra.git`. Secrets are managed by External Secrets Operator with a `ClusterSecretStore` named `openbao` (Vault-compatible, at `http://192.168.1.210:8200`). The current `eso-policy` covers only `secret/data/homelab/ci` and must be extended. Services are exposed via MetalLB LoadBalancer; Traefik is the ingress controller but not currently used for intranet services.

**AIOStreams:** Open-source Stremio addon aggregator by Viren070. Self-hosted via `ghcr.io/viren070/aiostreams`. Requires `SECRET_KEY` (64-char hex) and `BASE_URL`. Filtering is configured through a web UI but can be pre-seeded via `WHITELISTED_REGEX_PATTERNS` env var. Real-Debrid credentials injected via `FORCED_SERVICE_CREDENTIALS`.

## Constraints

- **GitOps:** All workloads must be declared as k8s manifests in `infra/kubernetes/<app>/` and managed via an ArgoCD `Application` CR in `infra/argocd/apps/` — no imperative `kubectl apply`
- **Secrets:** No credentials in git. All secrets via `ExternalSecret` → `ClusterSecretStore/openbao` pattern (ADR-011)
- **eso-policy scope:** The existing Kubernetes auth role `eso-reader` is currently scoped to `secret/data/homelab/ci` — expanding to `secret/data/aiostreams/*` is a prerequisite for ESO sync to work
- **Network isolation:** AIOStreams must not be reachable from outside the LAN — MetalLB LB address is sufficient; no port forwarding or ingress with external TLS termination
- **`FORCED_SERVICE_CREDENTIALS` format:** Must be verified against the AIOStreams `.env.sample` before writing to OpenBao — the env var format `serviceId.credentialId=value` is documented but the exact Real-Debrid service/credential IDs need confirmation

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| AIOStreams over Comet | Both support RD and filtering; AIOStreams is more actively maintained as an addon aggregator | Confirmed — Phase 2 |
| MetalLB LoadBalancer over Traefik IngressRoute | Consistent with existing mcp-servers pattern; hostname migration is future platform-wide work | Confirmed — Phase 2 |
| `secret/aiostreams/production` OpenBao path | Matches naming convention established in the provision-app-secrets runbook | Confirmed — Phase 1 |
| SQLite PVC over PostgreSQL | Single-user instance; no existing Postgres to point at; PVC is lowest-friction option | Confirmed — Phase 2 |
| Intranet-only exposure | Stremio is used only on LAN devices; no reason to expose AIOStreams externally | Confirmed — Phase 2 |
| `ANIME_DB_LEVEL_OF_DETAIL=none` | v2.29.5 loads 42K+ anime metadata entries at startup regardless of anime usage; disabling avoids OOMKill within 256Mi limit | Confirmed — Phase 2 |

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition** (via `/gsd-transition`):
1. Requirements invalidated? → Move to Out of Scope with reason
2. Requirements validated? → Move to Validated with phase reference
3. New requirements emerged? → Add to Active
4. Decisions to log? → Add to Key Decisions
5. "What This Is" still accurate? → Update if drifted

**After each milestone** (via `/gsd-complete-milestone`):
1. Full review of all sections
2. Core Value check — still the right priority?
3. Audit Out of Scope — reasons still valid?
4. Update Context with current state

---
**Current State:** Phase 2 complete — AIOStreams pod running, ArgoCD-managed, responding HTTP 200 on `192.168.1.205:3000`. Phase 3 remaining: UI setup runbook + ADR.

*Last updated: 2026-05-13 after Phase 2 completion*
