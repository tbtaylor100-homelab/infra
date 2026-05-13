---
phase: 02-kubernetes-manifests
plan: "02"
subsystem: kubernetes
tags: [deployment, pvc, service, argocd, metallb, aiostreams]
dependency_graph:
  requires:
    - 02-01 (namespace.yaml + external-secret.yaml + configmap.yaml — consumed by Deployment via envFrom)
  provides:
    - kubernetes/aiostreams/deployment.yaml (Deployment + PVC + Service)
    - argocd/apps/aiostreams.yaml (ArgoCD Application CR)
  affects:
    - ArgoCD: new Application CR causes auto-sync of all kubernetes/aiostreams/ manifests once pushed to main
tech_stack:
  added:
    - Kubernetes Deployment (apps/v1) with HTTP health probes
    - Kubernetes PersistentVolumeClaim (v1, local-path StorageClass, 10Gi)
    - Kubernetes Service (v1, type LoadBalancer, MetalLB IP pinning)
    - ArgoCD Application CR (argoproj.io/v1alpha1)
  patterns:
    - envFrom with secretRef + configMapRef for environment injection
    - MetalLB LoadBalancer with pinned IP via metallb.universe.tf/loadBalancerIPs annotation
    - Multi-document YAML (Deployment + PVC + Service in one file)
    - ArgoCD Application with automated prune + selfHeal sync policy
key_files:
  created:
    - kubernetes/aiostreams/deployment.yaml
    - argocd/apps/aiostreams.yaml
  modified: []
decisions:
  - "annotations under metadata (not spec) for Service — common YAML placement mistake avoided"
  - "envFrom order: secretRef first, configMapRef second — ensures secret keys take precedence if overlap occurs (no overlap expected)"
  - "Service annotations placed under metadata per Kubernetes API spec"
metrics:
  duration: "~1m"
  completed: "2026-05-13T03:00:35Z"
  tasks_completed: 2
  tasks_total: 2
  files_created: 2
  files_modified: 0
---

# Phase 2 Plan 02: Deployment, PVC, Service, and ArgoCD Application Summary

**One-liner:** Kubernetes Deployment (v2.29.5 image, HTTP probes, envFrom secret+configmap, PVC-backed SQLite) + MetalLB LoadBalancer Service (192.168.1.205:3000) + ArgoCD Application CR (auto-sync from kubernetes/aiostreams on main).

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Create deployment.yaml (Deployment + PVC + Service) | 92c67cd | kubernetes/aiostreams/deployment.yaml |
| 2 | Create argocd/apps/aiostreams.yaml | a869dff | argocd/apps/aiostreams.yaml |

## What Was Built

### Task 1: kubernetes/aiostreams/deployment.yaml

A multi-document YAML containing three Kubernetes resources:

**Deployment** (`apps/v1`):
- Image: `ghcr.io/viren070/aiostreams:v2.29.5` (pinned, no `latest`)
- Replicas: 1 (required for local-path PVC ReadWriteOnce)
- `envFrom` injects `aiostreams-secret` (secretRef, from ExternalSecret) and `aiostreams-config` (configMapRef)
- `env` adds `BASE_URL=http://192.168.1.205:3000` and `DATABASE_URI=sqlite://./data/db.sqlite`
- Liveness probe: `GET /api/v1/status:3000`, initialDelay 10s, period 10s, timeout 5s, failureThreshold 3
- Readiness probe: `GET /api/v1/status:3000`, initialDelay 5s, period 5s, timeout 3s, failureThreshold 2
- Resources: requests 100m/128Mi, limits 500m/256Mi
- Volume mount: `/app/data` backed by PVC `aiostreams-sqlite`
- `terminationGracePeriodSeconds: 30`

**PersistentVolumeClaim** (`v1`):
- Name: `aiostreams-sqlite`, namespace: `aiostreams`
- StorageClass: `local-path` (k3s default)
- Access mode: `ReadWriteOnce`
- Capacity: 10Gi

**Service** (`v1`):
- Type: `LoadBalancer`
- Annotation under `metadata`: `metallb.universe.tf/loadBalancerIPs: "192.168.1.205"`
- Selector: `app: aiostreams`
- Port: 3000 → targetPort 3000, TCP

### Task 2: argocd/apps/aiostreams.yaml

ArgoCD `Application` CR (verbatim copy of `argocd/apps/mcp-servers.yaml` with three field changes):
- `metadata.name`: `aiostreams`
- `spec.source.path`: `kubernetes/aiostreams`
- `spec.destination.namespace`: `aiostreams`
- `repoURL`, `targetRevision`, `project`, `syncPolicy` all identical to mcp-servers template

## Verification Results

| Check | Result |
|-------|--------|
| Both files exist | PASS |
| Image is `ghcr.io/viren070/aiostreams:v2.29.5` | PASS |
| Both probes present (`/api/v1/status` count = 2) | PASS |
| No inline secrets (no `secret_key`, `forced_service`, `apikey`, `realdebrid` literals) | PASS |
| MetalLB annotation `192.168.1.205` in Service metadata | PASS |
| ArgoCD `path: kubernetes/aiostreams` | PASS |
| PVC name `aiostreams-sqlite` appears in both PVC metadata and volume claimName (count = 2) | PASS |

## Threat Model Mitigations Applied

| Threat ID | Status | Implementation |
|-----------|--------|----------------|
| T-02-04 (credential exposure) | Mitigated | No `SECRET_KEY` or `FORCED_SERVICE_CREDENTIALS` literals in deployment.yaml; injected via `envFrom.secretRef` only |
| T-02-05 (availability — probes) | Mitigated | Both liveness and readiness HTTP probes on `/api/v1/status:3000` with appropriate failure thresholds |
| T-02-06 (availability — PVC) | Mitigated | local-path PVC, replicas=1, 10Gi capacity |
| T-02-07 (ArgoCD selfHeal) | Accepted | `selfHeal: true` and `prune: true` intentional GitOps controls |

## Deviations from Plan

None — plan executed exactly as written.

**Note on annotation placement:** The plan explicitly warned that the MetalLB `annotations` field must be under `metadata`, not `spec`. This was applied correctly — annotation is under `metadata.annotations` in the Service document.

## Known Stubs

None. All fields are wired to real values:
- Image: pinned `ghcr.io/viren070/aiostreams:v2.29.5`
- `BASE_URL`: `http://192.168.1.205:3000` (concrete MetalLB IP)
- `DATABASE_URI`: `sqlite://./data/db.sqlite` (concrete path in mounted PVC)
- Secret/ConfigMap refs: concrete names `aiostreams-secret` and `aiostreams-config` (produced by Plan 01)
- PVC: concrete name `aiostreams-sqlite` with 10Gi and `local-path` StorageClass

## Threat Flags

None. No new security-relevant surface introduced beyond what the plan's threat model covers.

## Self-Check: PASSED

- `kubernetes/aiostreams/deployment.yaml` exists: FOUND
- `argocd/apps/aiostreams.yaml` exists: FOUND
- Commit `92c67cd` exists: FOUND (feat(02-02): create aiostreams Deployment, PVC, and Service manifests)
- Commit `a869dff` exists: FOUND (feat(02-02): create ArgoCD Application CR for aiostreams)
