# CLAUDE.md — infra

## Active Project

**AIOStreams: Stremio Filtering Layer**
Deploy AIOStreams on k3s as a filtering proxy between Stremio and Torrentio/Real-Debrid, removing RD-blocked streams before they surface in the UI.

Planning: `.planning/` | State: `.planning/STATE.md` | Roadmap: `.planning/ROADMAP.md`

## GSD Workflow

This project uses the Get Shit Done (GSD) workflow.

**Current phase:** Phase 1 — Secrets & Prerequisites (Wave 1 complete, Wave 2 pending)
**Next command:** Resume `/gsd-execute-phase 1` after running `bao` commands from the provisioning runbook

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

## Phase 1 Status (Wave 1 complete — 2026-05-12)

Wave 1 artifacts committed:
- `kubernetes/external-secrets/eso-policy.hcl` — policy file with both paths (homelab/ci + aiostreams/*)
- `homelab-knowledge/runbooks/provision-aiostreams-secrets.md` — full provisioning runbook

Wave 2 (plan 01-03) requires running the runbook manually with `bao` or `vault` CLI:
1. `bao policy write -address=http://192.168.1.210:8200 eso-policy kubernetes/external-secrets/eso-policy.hcl`
2. `openssl rand -hex 32` → capture as SECRET_KEY
3. `bao kv put -address=http://192.168.1.210:8200 secret/aiostreams/production SECRET_KEY="$SECRET_KEY" FORCED_SERVICE_CREDENTIALS="realdebrid.apiKey=<key>"`
4. Verify with `bao kv get -address=http://192.168.1.210:8200 secret/aiostreams/production`

Install bao/vault CLI on Mac: `brew install openbao` or `brew install vault`

After running the bao commands, resume in Claude Code and tell it "secrets provisioned" to complete Phase 1.
