---
phase: 02-kubernetes-manifests
reviewed: 2026-05-13T00:00:00Z
depth: standard
files_reviewed: 5
files_reviewed_list:
  - argocd/apps/aiostreams.yaml
  - kubernetes/aiostreams/configmap.yaml
  - kubernetes/aiostreams/deployment.yaml
  - kubernetes/aiostreams/external-secret.yaml
  - kubernetes/aiostreams/namespace.yaml
findings:
  critical: 0
  warning: 4
  info: 3
  total: 7
status: issues_found
---

# Phase 02: Code Review Report

**Reviewed:** 2026-05-13T00:00:00Z
**Depth:** standard
**Files Reviewed:** 5
**Status:** issues_found

## Summary

Five Kubernetes manifests were reviewed covering the full AIOStreams workload: ArgoCD Application CR, ConfigMap, Deployment (+ PVC + Service), ExternalSecret, and Namespace. No critical security vulnerabilities were found. Four warnings were identified: a RollingUpdate + ReadWriteOnce PVC deadlock that will stall every rollout, an unverifiable ExternalSecret path that could silently break secret sync, a `CreateNamespace=true` that undermines sync-wave ordering, and a missing `podSecurityContext` leaving the container running as root. Three informational items round out the review.

## Warnings

### WR-01: RollingUpdate strategy + ReadWriteOnce PVC causes rollout deadlock

**File:** `kubernetes/aiostreams/deployment.yaml:1` (Deployment spec — no explicit `strategy` field)

**Issue:** The Deployment uses the default `RollingUpdate` strategy (`maxSurge: 1`). During a rollout, Kubernetes creates the new pod before terminating the old one. The PVC (`aiostreams-sqlite`) uses `accessModes: ReadWriteOnce`, which permits only one node-level attachment at a time. The new pod will fail to attach the volume while the old pod holds it, and will remain `Pending`/`ContainerCreating` indefinitely. The rollout stalls until the old pod is manually deleted or times out — meaning every image upgrade requires manual intervention.

**Fix:** Add an explicit `Recreate` strategy to the Deployment, which terminates the old pod before starting the new one:

```yaml
spec:
  replicas: 1
  strategy:
    type: Recreate
  selector:
    matchLabels:
      app: aiostreams
```

`Recreate` is the correct and only safe strategy for single-replica workloads backed by a `ReadWriteOnce` PVC.

---

### WR-02: ExternalSecret path may not match OpenBao KV mount — silent secret sync failure

**File:** `kubernetes/aiostreams/external-secret.yaml:19-24`

**Issue:** The `remoteRef.key` is `aiostreams/production` (without a `secret/` prefix). CLAUDE.md documents the path convention as `secret/<app>/<env>`, and the Phase 1 provisioning runbook writes secrets to `secret/aiostreams/production`. Whether the ClusterSecretStore `openbao` prepends the KV mount path (`secret/`) cannot be confirmed without reading its definition. If the store is configured without a `path` prefix, the effective lookup path will be `aiostreams/production`, which does not exist in OpenBao. The ExternalSecret will enter an error state and the Kubernetes Secret will never be created, causing the Deployment to fail to start (missing `aiostreams-secret`). The failure is not obvious until sync time.

**Fix:** Verify the `ClusterSecretStore/openbao` definition. If its `server.path` or equivalent does not include `secret/`, update the key:

```yaml
remoteRef:
  key: secret/aiostreams/production
  property: SECRET_KEY
```

Apply the same correction to the `FORCED_SERVICE_CREDENTIALS` entry (line 22). Alternatively, confirm the store adds the mount prefix and document that assumption in a comment.

---

### WR-03: `CreateNamespace=true` in ArgoCD syncOptions conflicts with sync-wave Namespace resource

**File:** `argocd/apps/aiostreams.yaml:20`

**Issue:** The ArgoCD Application sets `CreateNamespace=true`. This instructs ArgoCD to imperatively create the namespace as a pre-sync step, before any resources (including wave -2 resources) are applied. The dedicated `namespace.yaml` manifest carries `argocd.argoproj.io/sync-wave: "-2"` — but if ArgoCD already created the namespace via `CreateNamespace=true`, the wave -2 resource becomes a no-op patch on an already-existing namespace. This is harmless today but creates a maintenance trap: any labels or annotations added to `namespace.yaml` in the future (e.g., `pod-security.kubernetes.io/enforce`) will appear to apply correctly during `kubectl apply` dry-runs but may not take effect if the namespace was created without them and the sync does not update it. The two mechanisms are redundant and the interaction is non-obvious.

**Fix:** Remove `CreateNamespace=true` since the namespace is explicitly managed as a manifest:

```yaml
syncPolicy:
  automated:
    prune: true
    selfHeal: true
  syncOptions: []
```

The `namespace.yaml` with wave -2 is the correct and complete mechanism. Removing `CreateNamespace=true` makes the intent explicit.

---

### WR-04: Container runs as root — no securityContext defined

**File:** `kubernetes/aiostreams/deployment.yaml:16-38` (container spec)

**Issue:** No `securityContext` is set on the pod or container. Unless the `ghcr.io/viren070/aiostreams` image sets a non-root `USER` directive in its Dockerfile, the process runs as UID 0 (root) inside the container. Combined with the absence of a namespace-level PodSecurity label (`namespace.yaml` has no `pod-security.kubernetes.io/enforce` label), there is no policy enforcement preventing privilege escalation.

**Fix:** Add a restrictive security context. At minimum:

```yaml
spec:
  template:
    spec:
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
        fsGroup: 1000
      containers:
        - name: aiostreams
          securityContext:
            allowPrivilegeEscalation: false
            readOnlyRootFilesystem: false   # SQLite writes to /app/data via PVC
            capabilities:
              drop:
                - ALL
```

Note: `readOnlyRootFilesystem: true` may break the app if it writes outside `/app/data`. Verify the image's runtime write requirements first. If the upstream image requires root, document the exception with a comment.

---

## Info

### IN-01: `WHITELISTED_REGEX_PATTERNS` uses JS regex literal syntax in a JSON string

**File:** `kubernetes/aiostreams/configmap.yaml:7`

**Issue:** The value `'["/(?:WEB-DL|AMZN|DSNP|YTS|RARBG|EZTV)/i"]'` wraps a JavaScript regex literal (`/pattern/i`) inside a JSON array string. JSON has no regex type — this is a string that happens to look like a JS regex literal. Whether AIOStreams parses this correctly (e.g., strips the surrounding `/` and extracts flags) is application-specific. If the app uses `JSON.parse()` and then feeds the result directly to `new RegExp()` without stripping the JS literal syntax, the pattern string would be `/(?:WEB-DL|AMZN|DSNP|YTS|RARBG|EZTV)/i` verbatim, causing incorrect matching (the literal slashes would be included).

**Fix:** Confirm via AIOStreams documentation or source what format `WHITELISTED_REGEX_PATTERNS` expects. If it expects plain regex strings without the JS literal delimiters, use:

```yaml
WHITELISTED_REGEX_PATTERNS: '["(?:WEB-DL|AMZN|DSNP|YTS|RARBG|EZTV)"]'
```

CLAUDE.md's stated requirement that this be "a valid JSON array string" is met by the current value syntactically, but the semantic correctness depends on how AIOStreams consumes it.

---

### IN-02: `BASE_URL` hardcodes a LAN IP that must stay in sync with MetalLB annotation

**File:** `kubernetes/aiostreams/deployment.yaml:25` and `deployment.yaml:84`

**Issue:** The IP `192.168.1.205` appears in two places: `BASE_URL: "http://192.168.1.205:3000"` (env var) and `metallb.universe.tf/loadBalancerIPs: "192.168.1.205"` (Service annotation). If the MetalLB IP assignment changes, both must be updated atomically. There is no enforcement of this coupling.

**Fix:** This is acceptable for a homelab context, but add a comment to each location referencing the other to make the coupling explicit:

```yaml
# deployment.yaml env section
- name: BASE_URL
  value: "http://192.168.1.205:3000"  # Must match metallb.universe.tf/loadBalancerIPs in Service

# Service annotations
metallb.universe.tf/loadBalancerIPs: "192.168.1.205"  # Must match BASE_URL env var in Deployment
```

Long-term, consider switching to a DNS hostname (via split-horizon DNS or a local entry) so the IP appears only in the MetalLB annotation.

---

### IN-03: `PORT` in ConfigMap is redundant with hardcoded port values in Deployment

**File:** `kubernetes/aiostreams/configmap.yaml:9`, `kubernetes/aiostreams/deployment.yaml:21`, `deployment.yaml:43`, `deployment.yaml:50`

**Issue:** `PORT: "3000"` is set in the ConfigMap and loaded via `envFrom`. The same port is also hardcoded in `containerPort: 3000`, probe `port: 3000` (lines 43 and 50), and `BASE_URL`. The ConfigMap `PORT` would only be meaningful if the probes and `BASE_URL` referenced it, but they do not — they all hardcode `3000` independently. If someone changes `PORT` in the ConfigMap expecting all references to follow, probes and the Service `targetPort` will not update.

**Fix:** Either make all port references consistent by using a named port (`name: http` is already set on `containerPort`), or accept the duplication and add a comment. Probes can reference the named port:

```yaml
livenessProbe:
  httpGet:
    path: /api/v1/status
    port: http   # References containerPort name, not a hardcoded number
```

---

_Reviewed: 2026-05-13T00:00:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
