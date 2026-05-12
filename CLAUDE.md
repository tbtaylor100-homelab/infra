# CLAUDE.md — infra

## Active Project

**AIOStreams: Stremio Filtering Layer**
Deploy AIOStreams on k3s as a filtering proxy between Stremio and Torrentio/Real-Debrid, removing RD-blocked streams before they surface in the UI.

Planning: `.planning/` | State: `.planning/STATE.md` | Roadmap: `.planning/ROADMAP.md`

## GSD Workflow

This project uses the Get Shit Done (GSD) workflow.

**Current phase:** Phase 1 — Secrets & Prerequisites
**Next command:** `/gsd-plan-phase 1`

**Workflow enforcement:**
- Do not skip phases or execute work outside the active plan
- Each phase must be planned (`/gsd-plan-phase N`) before execution
- Verify requirements are met before marking a phase complete
- Update `.planning/STATE.md` at each phase transition

**Phase sequence:**
1. Secrets & Prerequisites — OpenBao policy, SECRET_KEY, RD credentials, provisioning runbook
2. Kubernetes Manifests — namespace, ExternalSecret, Deployment, PVC, Service, ArgoCD App
3. Configuration & Documentation — AIOStreams UI setup, filter validation, ADR

## Infra Conventions

**GitOps:** All workloads in `kubernetes/<app>/`, ArgoCD `Application` CR in `argocd/apps/<app>.yaml`.
Manifests are raw YAML — no Helm for own services. ArgoCD watches `http://forgejo.local:3000/root/infra.git` on `main`.

**Secrets:** No credentials in git. All secrets via `ExternalSecret` → `ClusterSecretStore/openbao`.
OpenBao at `http://192.168.1.210:8200`, path convention `secret/<app>/<env>`.

**Networking:** Services exposed via MetalLB `LoadBalancer` type. Traefik available as ingress controller for future hostname migration.

**ADRs:** Architectural decisions documented in `../homelab-knowledge/adr/`. Follow existing ADR format and numbering (next: ADR-016).

## Key Technical Facts (AIOStreams)

- Image: `ghcr.io/viren070/aiostreams:v2.29.5`
- Health probe: `GET /api/v1/status` (port 3000)
- DB path: `/app/data/db.sqlite` (PVC at `/app/data`)
- `SECRET_KEY` is immutable — changing it invalidates all saved user configs
- `FORCED_SERVICE_CREDENTIALS` format: `realdebrid.apiKey=<key>`
- `WHITELISTED_REGEX_PATTERNS` must be a valid JSON array string
- `REGEX_FILTER_ACCESS=all` required for filter to be available without per-user trust config

## ESO Policy Note

The current `eso-policy` covers only `secret/data/homelab/ci`. Phase 1 must extend it to include `secret/data/aiostreams/*` before Phase 2 manifests will sync.
