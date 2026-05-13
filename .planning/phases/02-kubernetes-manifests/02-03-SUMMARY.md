---
plan: 02-03
phase: 02-kubernetes-manifests
status: complete
completed: 2026-05-13
wave: 2
---

# Plan 02-03: Deployment Verification

## What Was Built

Committed and pushed all manifests from Plans 01 and 02 to main via PR #46. Bootstrapped the ArgoCD Application CR manually (`kubectl apply`) since there is no app-of-apps watching `argocd/apps/`. ArgoCD synced `kubernetes/aiostreams/` and brought up the full deployment stack.

## Issues Encountered and Resolved

**Issue 1 — ArgoCD repoURL 301 redirect (pre-existing cluster issue)**
All three Forgejo-backed Application CRs (`aiostreams`, `forgejo-runner`, `mcp-servers`) referenced `root/infra.git` but the repo lives at `tbtaylor100/infra.git`. ArgoCD doesn't follow git protocol redirects. Fixed by patching in-cluster CRs immediately and updating git manifests in PR #47.

**Issue 2 — OOMKill at startup**
AIOStreams v2.29.5 loads 42K+ Fribb anime metadata entries + Manami DB + Seadex at startup regardless of whether anime features are used. Exceeded 256Mi limit. Root cause was not memory headroom but an unnecessary feature: set `ANIME_DB_LEVEL_OF_DETAIL=none` in the ConfigMap (PR #48) to skip all anime DB loading entirely. Memory limits restored to original 256Mi/128Mi after PR #48 landed; PR #47 had temporarily raised them to 512Mi.

**Issue 3 — ConfigMap change requires manual rollout**
ArgoCD syncs ConfigMap content but does not restart pods on ConfigMap changes. Ran `kubectl rollout restart deployment/aiostreams -n aiostreams` to pick up the new env var.

## Verification Results

| Check | Result |
|-------|--------|
| Namespace aiostreams | Active |
| ExternalSecret aiostreams-secret | READY: True, SecretSynced |
| k8s Secret aiostreams-secret | Exists, Opaque, 2 keys |
| Deployment | 1/1 Ready, 0 restarts |
| PVC aiostreams-sqlite | Bound, 10Gi, local-path |
| Service EXTERNAL-IP | 192.168.1.205 |
| ArgoCD Application | Synced + Healthy |
| curl http://192.168.1.205:3000/api/v1/status | HTTP 200, `{"success":true,"data":{"version":"2.29.5"}}` |

## Key Files

- `kubernetes/aiostreams/namespace.yaml` — Applied, namespace Active
- `kubernetes/aiostreams/configmap.yaml` — Applied, includes ANIME_DB_LEVEL_OF_DETAIL=none
- `kubernetes/aiostreams/external-secret.yaml` — Applied, SecretSynced
- `kubernetes/aiostreams/deployment.yaml` — Applied, 1/1 Running
- `argocd/apps/aiostreams.yaml` — Applied, ArgoCD managing kubernetes/aiostreams/

## Self-Check: PASSED
