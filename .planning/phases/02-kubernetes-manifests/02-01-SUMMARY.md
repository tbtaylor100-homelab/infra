---
phase: 02-kubernetes-manifests
plan: "01"
subsystem: infra
tags: [kubernetes, argocd, external-secrets, openbao, aiostreams]

# Dependency graph
requires:
  - phase: 01-secrets-and-prerequisites
    provides: ClusterSecretStore/openbao deployed; eso-policy extended to secret/data/aiostreams/*; SECRET_KEY and FORCED_SERVICE_CREDENTIALS stored in OpenBao at aiostreams/production
provides:
  - kubernetes/aiostreams/namespace.yaml — Namespace aiostreams with sync-wave -2
  - kubernetes/aiostreams/configmap.yaml — ConfigMap aiostreams-config with WHITELISTED_REGEX_PATTERNS, REGEX_FILTER_ACCESS, PORT
  - kubernetes/aiostreams/external-secret.yaml — ExternalSecret pulling SECRET_KEY and FORCED_SERVICE_CREDENTIALS from ClusterSecretStore/openbao
affects:
  - 02-02 (Deployment, PVC, Service, ArgoCD App — all depend on this namespace, ConfigMap, and ExternalSecret)
  - 03-configuration-and-documentation (filter validation depends on pod startup which depends on ESO sync)

# Tech tracking
tech-stack:
  added:
    - external-secrets.io/v1beta1 ExternalSecret CRD (first ESO workload in cluster)
  patterns:
    - ArgoCD sync-wave ordering: namespace at -2, ExternalSecret at -1, Deployment at 0 (default)
    - ExternalSecret remoteRef.key without secret/ prefix — ESO adds KV v2 path automatically for Vault provider
    - Single-quoted JSON array for WHITELISTED_REGEX_PATTERNS in YAML ConfigMap

key-files:
  created:
    - kubernetes/aiostreams/namespace.yaml
    - kubernetes/aiostreams/configmap.yaml
    - kubernetes/aiostreams/external-secret.yaml
  modified: []

key-decisions:
  - "sync-wave -2 on Namespace ensures ArgoCD creates it before ExternalSecret (wave -1) — without this, ExternalSecret validation fails with namespace not found"
  - "remoteRef.key: aiostreams/production (no secret/ prefix) — ESO prepends secret/data/ automatically for Vault KV v2; using the full path causes double-path errors"
  - "WHITELISTED_REGEX_PATTERNS as single-quoted JSON array in YAML — avoids escaping forward slashes and ensures AIOStreams receives a valid JSON array (not plain text)"
  - "creationPolicy: Owner on ExternalSecret target — ESO owns the resulting Secret and cleans it up if the ExternalSecret is deleted"
  - "refreshInterval: 1h — SECRET_KEY is immutable and FORCED_SERVICE_CREDENTIALS rarely changes; hourly polling avoids unnecessary OpenBao API calls"

patterns-established:
  - "ExternalSecret pattern: apiVersion external-secrets.io/v1beta1, secretStoreRef openbao/ClusterSecretStore, remoteRef.key = <app>/<env> (no secret/ prefix), creationPolicy Owner"
  - "ArgoCD sync-wave ordering for namespace-first resource creation"
  - "ConfigMap for evolving non-secret config (WHITELISTED_REGEX_PATTERNS expected to evolve quarterly)"

requirements-completed:
  - K8S-01
  - K8S-06

# Metrics
duration: 2min
completed: 2026-05-13
---

# Phase 2 Plan 01: Kubernetes Foundational Manifests Summary

**Namespace, ConfigMap, and ExternalSecret manifests for aiostreams namespace with ArgoCD sync-wave ordering and ESO credential sync from ClusterSecretStore/openbao**

## Performance

- **Duration:** 2 min
- **Started:** 2026-05-13T02:58:04Z
- **Completed:** 2026-05-13T02:59:20Z
- **Tasks:** 3
- **Files modified:** 3

## Accomplishments

- Created `kubernetes/aiostreams/namespace.yaml` with sync-wave -2, ensuring ArgoCD creates the namespace before any other aiostreams resource
- Created `kubernetes/aiostreams/configmap.yaml` with WHITELISTED_REGEX_PATTERNS as a valid JSON array targeting RD-blocked release tags (WEB-DL, AMZN, DSNP, YTS, RARBG, EZTV), REGEX_FILTER_ACCESS=all, and PORT=3000
- Created `kubernetes/aiostreams/external-secret.yaml` — first ESO workload in the cluster — syncing SECRET_KEY and FORCED_SERVICE_CREDENTIALS from ClusterSecretStore/openbao at path aiostreams/production, with sync-wave -1 and creationPolicy Owner

## Task Commits

Each task was committed atomically:

1. **Task 1: Create namespace.yaml** - `c4adfcc` (feat)
2. **Task 2: Create configmap.yaml** - `c54fc10` (feat)
3. **Task 3: Create external-secret.yaml** - `3dee2db` (feat)

## Files Created/Modified

- `kubernetes/aiostreams/namespace.yaml` — Namespace aiostreams, sync-wave -2 for ArgoCD ordering
- `kubernetes/aiostreams/configmap.yaml` — Non-secret configuration: regex patterns, filter access, port
- `kubernetes/aiostreams/external-secret.yaml` — ESO CR pulling SECRET_KEY and FORCED_SERVICE_CREDENTIALS from OpenBao

## Decisions Made

- Sync-wave -2 on Namespace and -1 on ExternalSecret per RESEARCH.md Pitfall 3 — prevents "namespace not found" failures during ArgoCD sync
- `remoteRef.key: aiostreams/production` without `secret/` prefix — ESO handles KV v2 path prepending automatically per RESEARCH.md Pattern 1 critical detail
- Single-quoted YAML scalar for WHITELISTED_REGEX_PATTERNS — cleanest way to embed JSON array with forward slashes without escaping (RESEARCH.md Pitfall 4 guidance)

## Deviations from Plan

None — plan executed exactly as written.

## Issues Encountered

None. Verification check 2 (no secrets committed) flagged `secretKey: SECRET_KEY` but this is the remoteRef field name mapping, not a literal credential value — expected and correct.

## User Setup Required

None — no external service configuration required for these manifest files. The prerequisites (OpenBao policy extended, secrets provisioned) are Phase 1 artifacts.

## Next Phase Readiness

Plan 02 can proceed: the namespace, ConfigMap, and ExternalSecret are in place as prerequisites for the Deployment, PVC, Service, and ArgoCD Application CR.

**Prerequisite reminder before ArgoCD sync:** Verify OpenBao policy includes `secret/data/aiostreams/*` with read capability and that `secret/aiostreams/production` contains SECRET_KEY and FORCED_SERVICE_CREDENTIALS (Phase 1 runbook must have been executed).

---
*Phase: 02-kubernetes-manifests*
*Completed: 2026-05-13*
