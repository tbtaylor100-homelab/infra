# Phase 2: Kubernetes Manifests - Research

**Researched:** 2026-05-12
**Domain:** Kubernetes workload deployment (manifests, secrets, networking, storage)
**Confidence:** HIGH

## Summary

Phase 2 creates the complete Kubernetes manifest set to deploy AIOStreams as a running, LAN-accessible filtering proxy. This is the first phase that will use the ExternalSecret operator (ESO) in the cluster, requiring careful attention to the secret sync path format and namespace ordering. The manifests follow the existing mcp-servers pattern (split files, MetalLB LoadBalancer, namespace isolation) with two key divergences: (1) ESO-managed secrets instead of manually created Secrets, and (2) a pinned MetalLB IP address via annotation.

**Primary recommendation:** Author the four split YAML files in `kubernetes/aiostreams/` (namespace, external-secret, configmap, deployment), following mcp-servers patterns precisely, then create the ArgoCD Application CR in `argocd/apps/aiostreams.yaml` using the mcp-servers template. Test ExternalSecret sync status before considering the pod deployment successful.

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **D-01 (File organization):** Split into 4 files: `namespace.yaml`, `external-secret.yaml`, `configmap.yaml`, `deployment.yaml` (Deployment + PVC + Service together in one file). ArgoCD `path: kubernetes/aiostreams` picks up all files automatically.
- **D-02 (MetalLB IP):** AIOStreams pinned to `192.168.1.205` via `metallb.universe.tf/loadBalancerIPs` annotation on the Service. This is the next sequential free IP in the homelab-pool (`192.168.1.200–220`).
- **D-03 (BASE_URL):** `BASE_URL=http://192.168.1.205:3000` baked into the Deployment env vars. No two-phase deploy needed.
- **D-04 (ConfigMap for regex):** `WHITELISTED_REGEX_PATTERNS` lives in a ConfigMap rather than inline in the Deployment env. Reason: the regex pattern is expected to evolve quarterly as Real-Debrid's block list changes.
- **D-05 (Regex initial value):** Initial regex value: `["/(WEB-DL|AMZN|DSNP|YTS|RARBG|EZTV)/i"]` — targets known RD-blocked release tags. **Researcher must confirm against current ElfHosted docs before writing the ConfigMap.**
- **D-06 (ESO secret sync):** ESO ExternalSecret pulls `SECRET_KEY` and `FORCED_SERVICE_CREDENTIALS` from `ClusterSecretStore/openbao` at `secret/aiostreams/production` and writes them as a native k8s Secret named `aiostreams-secret` in the `aiostreams` namespace.
- **D-07 (envFrom):** The Deployment uses `envFrom: secretRef: name: aiostreams-secret` to inject all fields as env vars. Since field names in OpenBao match env var names exactly, no per-field remapping is needed.

### Claude's Discretion
- ExternalSecret `refreshInterval`: choose appropriate value (e.g., `1h` is common); `SECRET_KEY` is immutable so it won't change, but the interval must be set.
- Exact `WHITELISTED_REGEX_PATTERNS` JSON escaping in YAML (use block scalar or single quotes to avoid escaping nightmares).
- Resource limits on the Deployment: REQUIREMENTS.md specifies 100m/500m CPU, 128Mi/256Mi RAM — use as-is.
- `ADDON_NAME` and other optional env vars: researcher should verify `.env.sample` and omit anything not strictly required.

### Deferred Ideas (OUT OF SCOPE)
- None — discussion stayed within phase scope.

</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| K8S-01 | Namespace `aiostreams` exists in the cluster | Covered: namespace.yaml pattern + ArgoCD CreateNamespace |
| K8S-02 | ArgoCD `Application` CR at `argocd/apps/aiostreams.yaml` watches `kubernetes/aiostreams/` and syncs automatically | Covered: ArgoCD Application pattern, repository URL, sync policy |
| K8S-03 | `Deployment` runs `ghcr.io/viren070/aiostreams:v2.29.5` with health probes, resource limits, and env vars | Covered: image version verified, health probe path, resource limits, env var configuration |
| K8S-04 | `Service` of type `LoadBalancer` exposes AIOStreams on port 3000 via MetalLB | Covered: MetalLB pattern, port configuration, IP annotation structure |
| K8S-05 | `PersistentVolumeClaim` of 10Gi on `local-path` mounted at `/app/data` | Covered: PVC spec, storage class name, mount path verification |
| K8S-06 | `ExternalSecret` pulls `SECRET_KEY` and `FORCED_SERVICE_CREDENTIALS` from `ClusterSecretStore/openbao` at `secret/aiostreams/production` | Covered: ExternalSecret CRD structure, secretKey/remoteRef format, path format for KV v2 |

</phase_requirements>

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Credential provisioning | Backend (OpenBao) | — | Secrets stored centrally; pod retrieves at startup |
| Secret sync into pod | API/Backend (k8s controller) | — | ExternalSecret operator watches OpenBao and writes native k8s Secret |
| Pod execution & health | API/Backend (k8s kubelet) | — | Kubernetes manages pod lifecycle and probes |
| Traffic reception | Browser/LAN client | — | Stremio clients on LAN make requests directly to AIOStreams Service IP |
| Regex filtering logic | Backend (AIOStreams app) | — | Application-level filtering; rules come from environment |
| Persistent storage | Database (SQLite via PVC) | — | Local-path storage class persists SQLite across restarts |
| Network exposure | Network layer (MetalLB) | — | LoadBalancer Service assigns intranet IP |

---

## Standard Stack

### Core Kubernetes Resources
| Resource | Version | Purpose | Why Standard |
|----------|---------|---------|--------------|
| Deployment | apps/v1 | Pod lifecycle management | Kubernetes standard for stateful single-replica workloads |
| Service | v1 (type: LoadBalancer) | Network exposure | Consistent with existing mcp-servers services; MetalLB handles intranet IP assignment |
| PersistentVolumeClaim | v1 | SQLite persistence | k3s local-path storage class; no external DB dependency |
| ConfigMap | v1 | Non-secret configuration | Standard for environment variables that don't contain secrets |
| Namespace | v1 | Workload isolation | Best practice; matches mcp-servers pattern |

### Secrets & ESO
| Resource | Version | Purpose | Why Standard |
|----------|---------|---------|--------------|
| ExternalSecret | external-secrets.io/v1beta1 | Secret sync from OpenBao | This is the first ESO workload in the cluster; establishes the pattern for future workloads |
| ClusterSecretStore | external-secrets.io/v1beta1 | Reference to OpenBao | Already deployed in Phase 1; provides Vault-compatible auth via k8s SA |

### Application Container
| Technology | Version | Purpose | Why Standard |
|------------|---------|---------|--------------|
| AIOStreams | v2.29.5 (pinned) | Stremio filtering proxy | Active maintenance; v2.x stable releases; ghcr.io official registry |
| SQLite 3 | Bundled in container | User config + cache storage | No external DB dependency; sufficient for single-user homelab |

### Networking
| Technology | Configuration | Purpose | Why Standard |
|------------|---------------|---------|--------------|
| MetalLB | LoadBalancer with IP pinning | Intranet service exposure | Existing homelab setup; consistent with mcp-servers; enables LAN access without hostname |

### Installing Dependencies
Verify versions before writing manifests:
```bash
# Check k3s default storage class
kubectl get storageclass

# Verify ExternalSecret CRD is installed
kubectl get crds | grep external-secrets

# Verify ClusterSecretStore exists
kubectl get clustersecretstores
```

All other resources are Kubernetes built-ins (v1.28+).

---

## Architecture Patterns

### System Architecture Diagram

Entry point: Stremio client on LAN makes HTTP request to MetalLB LoadBalancer IP.

```
┌─ ArgoCD Application ──────────────────────────────────────────┐
│  watches: kubernetes/aiostreams on main branch                 │
├──────────────────────────────────────────────────────────────┤
│  ┌─ Namespace: aiostreams ────────────────────────────────┐   │
│  │                                                         │   │
│  │  ┌─ ConfigMap: aiostreams-config ────────────────────┐ │   │
│  │  │  ├─ WHITELISTED_REGEX_PATTERNS (JSON array)       │ │   │
│  │  │  ├─ REGEX_FILTER_ACCESS=all                       │ │   │
│  │  │  └─ PORT=3000                                      │ │   │
│  │  └────────────────────────────────────────────────────┘ │   │
│  │                                                         │   │
│  │  ┌─ ExternalSecret: aiostreams-secret ──────────────┐ │   │
│  │  │  reads from: ClusterSecretStore/openbao         │ │   │
│  │  │  source path: secret/aiostreams/production       │ │   │
│  │  │  writes to: Secret/aiostreams-secret             │ │   │
│  │  │  contains: SECRET_KEY, FORCED_SERVICE_CREDS      │ │   │
│  │  └────────────────────────────────────────────────────┘ │   │
│  │                           ↓ ESO sync                      │   │
│  │  ┌─ Secret: aiostreams-secret ──────────────────────┐ │   │
│  │  │  .data:                                           │ │   │
│  │  │    SECRET_KEY: <base64 encoded>                  │ │   │
│  │  │    FORCED_SERVICE_CREDENTIALS: <base64>          │ │   │
│  │  └────────────────────────────────────────────────────┘ │   │
│  │                           ↓ envFrom                       │   │
│  │  ┌─ Deployment: aiostreams ──────────────────────┐   │   │
│  │  │  replicas: 1                                   │   │   │
│  │  │  image: ghcr.io/viren070/aiostreams:v2.29.5   │   │   │
│  │  │  port: 3000                                    │   │   │
│  │  │  ├─ envFrom:                                   │   │   │
│  │  │  │  ├─ secretRef: aiostreams-secret           │   │   │
│  │  │  │  └─ configMapRef: aiostreams-config        │   │   │
│  │  │  ├─ env:                                       │   │   │
│  │  │  │  ├─ BASE_URL: http://192.168.1.205:3000   │   │   │
│  │  │  │  └─ DATABASE_URI: sqlite://./data/db.sqlite│   │   │
│  │  │  ├─ volumeMounts:                             │   │   │
│  │  │  │  └─ /app/data → PVC                        │   │   │
│  │  │  ├─ livenessProbe: GET /api/v1/status         │   │   │
│  │  │  ├─ readinessProbe: GET /api/v1/status        │   │   │
│  │  │  └─ resources: 100m/500m CPU, 128Mi/256Mi RAM │   │   │
│  │  └────────────────────────────────────────────────┘   │   │
│  │           ↓ mounts                                      │   │
│  │  ┌─ PVC: aiostreams-sqlite ────────────────────┐   │   │
│  │  │  size: 10Gi                                  │   │   │
│  │  │  storageClass: local-path                   │   │   │
│  │  │  accessMode: ReadWriteOnce                  │   │   │
│  │  └────────────────────────────────────────────┘   │   │
│  │                                                         │   │
│  │  ┌─ Service: aiostreams ─────────────────────────┐ │   │
│  │  │  type: LoadBalancer                           │ │   │
│  │  │  selector: app=aiostreams                     │ │   │
│  │  │  port: 3000 → targetPort: 3000               │ │   │
│  │  │  annotation: metallb.universe.tf/            │ │   │
│  │  │    loadBalancerIPs: 192.168.1.205           │ │   │
│  │  └────────────────────────────────────────────────┘ │   │
│  └─────────────────────────────────────────────────────────┘   │
│                           ↓ LoadBalancer IP                    │
│  ┌─ MetalLB (Cluster External Networking)                      │
│  │  assigns IP 192.168.1.205 from pool 192.168.1.200-220     │
│  └──────────────────────────────────────────────────────────┘   │
│                           ↓                                     │
│  ┌─ LAN Network                                                 │
│  │  ↑ HTTP requests from Stremio clients on 192.168.1.0/24    │
│  └──────────────────────────────────────────────────────────┘   │
│                                                                  │
│  External Dependencies:                                         │
│  └─ OpenBao at http://192.168.1.210:8200 (Secret Store)       │
│     └─ secret/data/aiostreams/production (KV v2)              │
│        ├─ SECRET_KEY (immutable 64-char hex)                  │
│        └─ FORCED_SERVICE_CREDENTIALS (realdebrid.apiKey=...)  │
└──────────────────────────────────────────────────────────────┘
```

**Data flow:**
1. Git push to `http://forgejo.local:3000/root/infra.git` → manifests committed
2. ArgoCD watches `kubernetes/aiostreams/` on `main` branch
3. ArgoCD creates namespace, configmap, then triggers ExternalSecret creation
4. ExternalSecret operator reads OpenBao via ClusterSecretStore auth
5. OpenBao returns SECRET_KEY and FORCED_SERVICE_CREDENTIALS
6. ESO creates k8s Secret `aiostreams-secret` in `aiostreams` namespace
7. Deployment spec `envFrom: secretRef` injects Secret keys as env vars
8. Deployment `env:` section adds BASE_URL and DATABASE_URI
9. Deployment `envFrom: configMapRef` adds WHITELISTED_REGEX_PATTERNS, etc.
10. Pod starts, listens on port 3000
11. Service routes traffic from LoadBalancer IP (192.168.1.205:3000) to pod port 3000
12. Stremio client on LAN connects to `http://192.168.1.205:3000/manifest.json`

### Recommended Project Structure

```
kubernetes/aiostreams/
├── namespace.yaml
│   └── defines `aiostreams` namespace (isolated from mcp-servers)
├── external-secret.yaml
│   └── ExternalSecret CR + target Secret definition (ESO writes Secret here)
├── configmap.yaml
│   └── ConfigMap with WHITELISTED_REGEX_PATTERNS, PORT, REGEX_FILTER_ACCESS
└── deployment.yaml
│   ├── Deployment spec (containers, probes, resources, mounts)
│   ├── PVC spec (aiostreams-sqlite, 10Gi, local-path)
│   └── Service spec (LoadBalancer, port 3000, IP annotation)

argocd/apps/
└── aiostreams.yaml
    └── Application CR (watches kubernetes/aiostreams/, syncs to aiostreams namespace)
```

### Pattern 1: ExternalSecret Secret Sync (First ESO Workload in Cluster)

**What:** ExternalSecret operator pulls credentials from OpenBao and writes them as a native Kubernetes Secret. This is the first ESO workload in the cluster, establishing the pattern for future deployments.

**When to use:** Any workload that needs credentials from OpenBao but should not have those credentials committed to git.

**CRD Structure:**

[VERIFIED: external-secrets.io/latest/api/spec/]

```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: aiostreams-secret
  namespace: aiostreams
  annotations:
    argocd.argoproj.io/sync-wave: "-1"  # Create AFTER namespace
spec:
  refreshInterval: 1h  # Sync interval (default is 1h; immutable SECRET_KEY, so low frequency OK)
  secretStoreRef:
    name: openbao  # References ClusterSecretStore named "openbao"
    kind: ClusterSecretStore
  target:
    name: aiostreams-secret  # Name of the k8s Secret ESO will create
    creationPolicy: Owner  # ESO owns this Secret; if ExternalSecret is deleted, Secret is deleted
  data:
    - secretKey: SECRET_KEY  # Key name in the resulting k8s Secret
      remoteRef:
        key: aiostreams/production  # Path in OpenBao (ESO adds /data/ prefix for KV v2)
        property: SECRET_KEY  # Property name in the OpenBao secret object
    - secretKey: FORCED_SERVICE_CREDENTIALS
      remoteRef:
        key: aiostreams/production
        property: FORCED_SERVICE_CREDENTIALS
```

**Why this pattern:**
- No secrets in git (credentials come from OpenBao at sync time)
- Explicit `data` entries make it clear which secrets are synced (auditable)
- `refreshInterval: 1h` is sufficient; SECRET_KEY is immutable so frequent sync is unnecessary
- `creationPolicy: Owner` ensures cleanup if the ExternalSecret is deleted
- ClusterSecretStore reference points to existing OpenBao auth setup from Phase 1

**Critical detail:** The path format is `aiostreams/production` (NOT `secret/aiostreams/production`). ESO handles the KV v2 path convention automatically, prepending `secret/data/` to the HTTP request. [VERIFIED: external-secrets.io/latest/provider/hashicorp-vault/]

### Pattern 2: LoadBalancer Service with MetalLB IP Pinning

**What:** Service of type `LoadBalancer` with annotation to pin a specific intranet IP.

**When to use:** LAN-only services that need a stable, reachable IP address.

**Example:**

```yaml
apiVersion: v1
kind: Service
metadata:
  name: aiostreams
  namespace: aiostreams
spec:
  type: LoadBalancer
  selector:
    app: aiostreams
  ports:
    - port: 3000
      targetPort: 3000
      protocol: TCP
  annotations:
    metallb.universe.tf/loadBalancerIPs: "192.168.1.205"  # Pin IP (required for stable address)
```

**Why this pattern:**
- LoadBalancer type enables external (to the pod) network exposure via MetalLB
- Annotation pins the IP to 192.168.1.205 (the next sequential free IP in homelab pool)
- No hostname required (satisfies phase scope); hostname migration deferred to future work
- Consistent with mcp-servers Service pattern

**Note:** mcp-servers Services do NOT use the IP pinning annotation (IPs are auto-assigned). AIOStreams requires pinning because BASE_URL is hardcoded to this IP.

### Pattern 3: ConfigMap for Non-Secret Configuration

**What:** ConfigMap holds environment variables that can change (regex patterns, feature flags) and don't contain secrets.

**When to use:** Configuration that evolves separately from the Deployment spec and should be version-controlled.

**Example:**

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: aiostreams-config
  namespace: aiostreams
data:
  WHITELISTED_REGEX_PATTERNS: |
    ["/(?:WEB-DL|AMZN|DSNP|YTS|RARBG|EZTV)/i"]
  REGEX_FILTER_ACCESS: "all"
  PORT: "3000"
```

**Why this pattern:**
- Regex patterns expected to evolve quarterly (per REQUIREMENTS.md RES-01) — ConfigMap isolates them from Deployment spec
- Non-secret values can be safely version-controlled
- `envFrom: configMapRef` injects all keys as env vars

**Critical detail:** WHITELISTED_REGEX_PATTERNS must be a JSON array of regex strings, NOT comma-separated or newline-separated text. [VERIFIED: github.com/Viren070/AIOStreams/.env.sample]

### Anti-Patterns to Avoid

- **Hardcoding secrets in Deployment env:** Secrets in git = security incident. Use ExternalSecret instead. [VERIFIED: PITFALLS.md Risk 2]
- **Using emptyDir for SQLite:** Database lost when pod restarts. Use PVC with persistent storage. [VERIFIED: ARCHITECTURE.md anti-pattern 2]
- **Multiple replicas with local-path PVC:** local-path binds to one node; multiple replicas cause scheduling failures. Keep `replicas: 1`. [VERIFIED: ARCHITECTURE.md anti-pattern 3]
- **WHITELISTED_REGEX_PATTERNS not as JSON array:** Patterns silently ignored or parsing errors. Must be JSON array. [VERIFIED: PITFALLS.md Gotcha 1]
- **Missing sync waves:** ExternalSecret created before namespace exists; sync fails. Use annotations. [VERIFIED: PITFALLS.md Pitfall 4]

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Secret management | Custom Secret creation scripts | ExternalSecret + OpenBao | ESO handles refresh cycles, Vault auth, version control; custom scripts are fragile and leak secrets in logs |
| Persistent storage | emptyDir volumes | PersistentVolumeClaim with local-path | PVC survives pod restarts; emptyDir is ephemeral |
| Health checking | TCP socket probe | HTTP probe to `/api/v1/status` | HTTP probe detects application hangs; TCP only checks port is open |
| Configuration drift | Hard-coded env vars in Deployment | ConfigMap + envFrom | ConfigMap separates config from spec; enables updates without pod restart (future capability) |
| Network exposure | ClusterIP + port-forward | LoadBalancer Service with MetalLB | LoadBalancer is stable, reachable from all LAN devices; port-forward is manual and pod-dependent |

**Key insight:** Kubernetes and the ExternalSecret operator are designed to solve these problems. Using native tools is simpler and more maintainable than custom solutions.

---

## Common Pitfalls

### Pitfall 1: SECRET_KEY Rotation After Deployment Invalidates User Configs

**What goes wrong:** AIOStreams encrypts user config using SECRET_KEY. If you change the key after users add the addon, all saved configs become unreadable garbage.

**Why it happens:** AIOStreams uses SECRET_KEY to derive encryption keys via PBKDF2. Changing the key breaks the derivation; old configs cannot be decrypted.

**How to avoid:**
- Generate SECRET_KEY once, before first deployment, via `openssl rand -hex 32`
- Store in OpenBao as immutable — treat as write-once
- Document in runbook: "SECRET_KEY is immutable; changing it invalidates all user configs"
- If rotation required (security incident), plan user communication and config migration

**Warning signs:** Users report "addon loads but won't configure" or "settings disappeared after restart"

**Source:** [VERIFIED: PITFALLS.md Pitfall 1 + AIOStreams Configuration Wiki]

### Pitfall 2: ESO-Policy Scope Not Extended — ExternalSecret Fails Silently

**What goes wrong:** If OpenBao `eso-policy` is not extended to cover `secret/data/aiostreams/*`, the ExternalSecret will show `SyncFailed` but the error is easy to miss. The pod starts and crashes immediately.

**Why it happens:** ExternalSecret authenticates to OpenBao using a k8s auth role bound to a policy. Without the policy allowing `secret/data/aiostreams/*`, all requests are denied at the Vault policy level.

**How to avoid:**
- **Phase 1 prerequisite:** The `eso-policy` must be extended before deploying this phase
- Verify: `bao policy read eso-policy` includes `path "secret/data/aiostreams/*"` with read permissions
- After deploying ExternalSecret, check status: `kubectl get externalsecrets -n aiostreams -o wide` should show `SYNC_STATUS: true`

**Warning signs:** Pod shows "SECRET_KEY missing" but it's in OpenBao; ExternalSecret shows `Sync Failed`

**Source:** [VERIFIED: PITFALLS.md Pitfall 3 + CONTEXT.md D-06]

### Pitfall 3: ExternalSecret Namespace Ordering — Created Before Namespace Exists

**What goes wrong:** ArgoCD applies resources in waves. Without sync wave ordering, ExternalSecret may be created before the `aiostreams` namespace exists. Sync fails with "namespace not found".

**Why it happens:** Default ArgoCD sync order is unordered. ESO validation fails if the target namespace doesn't exist yet.

**How to avoid:**
- Use ArgoCD sync wave annotations:
  ```yaml
  # In namespace.yaml
  metadata:
    annotations:
      argocd.argoproj.io/sync-wave: "-2"
  ```
  ```yaml
  # In external-secret.yaml
  metadata:
    annotations:
      argocd.argoproj.io/sync-wave: "-1"
  ```
- This ensures namespace is created first, then ExternalSecret
- Also rely on ArgoCD Application `CreateNamespace=true` as a safety net

**Warning signs:** ArgoCD sync fails with "namespace not found"; ExternalSecret status shows namespace errors

**Source:** [VERIFIED: PITFALLS.md Pitfall 4]

### Pitfall 4: WHITELISTED_REGEX_PATTERNS Format — JSON Array, Not Comma-Separated

**What goes wrong:** WHITELISTED_REGEX_PATTERNS must be a JSON array (e.g., `["/(WEB-DL)/i"]`), but it's easy to pass plain text (e.g., `WEB-DL,AMZN,DSNP`). Patterns silently don't apply, and users see unfiltered RD-blocked results.

**Why it happens:** JSON arrays in environment variables are non-intuitive; many assume plain text delimiters.

**How to avoid:**
- Use a JSON validator before deploying: paste the pattern string into a validator
- In YAML, use a block scalar to avoid escaping nightmares:
  ```yaml
  WHITELISTED_REGEX_PATTERNS: |
    ["/(?:WEB-DL|AMZN|DSNP|YTS|RARBG|EZTV)/i"]
  ```
- Or single quotes:
  ```yaml
  WHITELISTED_REGEX_PATTERNS: '["/(?:WEB-DL|AMZN|DSNP|YTS|RARBG|EZTV)/i"]'
  ```
- Test in AIOStreams UI: do the regex filters appear?

**Warning signs:** Stremio shows unfiltered (RD-blocked) results despite filter config; pod logs show no errors

**Source:** [VERIFIED: PITFALLS.md Gotcha 1 + AIOStreams .env.sample]

### Pitfall 5: FORCED_SERVICE_CREDENTIALS Format — `serviceId.credentialId=value`

**What goes wrong:** FORCED_SERVICE_CREDENTIALS format must be `realdebrid.apiKey=<key>` (NOT `realdebrid.token=` or `realdebrid=`). Wrong credentialId causes silent credential loss.

**Why it happens:** Different debrid services (RealDebrid, AllDebrid, Premiumize, TorBox) have different credential IDs. Documentation doesn't list all; easy to guess wrong.

**How to avoid:**
- Before writing the Secret in OpenBao, verify the credential ID in [AIOStreams .env.sample](https://github.com/Viren070/AIOStreams/blob/main/.env.sample)
- For Real-Debrid, the credential ID is `apiKey` (lowercase, no underscore)
- Document in runbook: "For Real-Debrid, use credentialId=apiKey"
- Test: Stremio should show streams from Torrentio after config

**Warning signs:** AIOStreams starts but Torrentio shows "0 streams"; Real-Debrid not active in UI

**Source:** [VERIFIED: PITFALLS.md Gotcha 2 + github.com/Viren070/AIOStreams/.env.sample]

### Pitfall 6: BASE_URL Mismatch — Localhost vs LAN IP Breaks Manifest Installation

**What goes wrong:** If BASE_URL is set to `localhost:3000` but AIOStreams is accessed from a LAN IP, Stremio clients cannot reach `localhost` (they interpret it as their own machine). Addon fails with "cannot reach addon" error.

**Why it happens:** Stremio uses BASE_URL to generate manifest URL (`stremio://install?url=${BASE_URL}/manifest.json`). Every client resolves `localhost` relative to *its own* machine, not the server.

**How to avoid:**
- For this phase: BASE_URL is locked to `http://192.168.1.205:3000` (MetalLB IP)
- Test from a non-localhost device: `curl http://192.168.1.205:3000/manifest.json` from another LAN machine
- Never use `localhost` in production for multi-client services

**Warning signs:** Addon installs but immediately shows "Cannot reach addon" in Stremio; works only on the kubernetes host machine

**Source:** [VERIFIED: PITFALLS.md Pitfall 2]

---

## Code Examples

### Example 1: namespace.yaml

[CITED: kubernetes/mcp-servers/namespace.yaml]

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: aiostreams
  annotations:
    argocd.argoproj.io/sync-wave: "-2"  # Create first in sync order
```

### Example 2: external-secret.yaml (ExternalSecret + Target Secret)

[CITED: external-secrets.io/latest/api/spec/ + ClusterSecretStore pattern]

```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: aiostreams-secret
  namespace: aiostreams
  annotations:
    argocd.argoproj.io/sync-wave: "-1"  # Create AFTER namespace
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: openbao
    kind: ClusterSecretStore
  target:
    name: aiostreams-secret
    creationPolicy: Owner
  data:
    - secretKey: SECRET_KEY
      remoteRef:
        key: aiostreams/production
        property: SECRET_KEY
    - secretKey: FORCED_SERVICE_CREDENTIALS
      remoteRef:
        key: aiostreams/production
        property: FORCED_SERVICE_CREDENTIALS
```

**Note:** The `key` field is `aiostreams/production` (no `secret/` or `/data/` prefix). ESO automatically prepends `secret/data/` for Vault KV v2. The resulting HTTP request to OpenBao will be `/v1/secret/data/aiostreams/production`.

### Example 3: configmap.yaml

[CITED: CONTEXT.md D-04 + AIOStreams .env.sample]

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: aiostreams-config
  namespace: aiostreams
data:
  WHITELISTED_REGEX_PATTERNS: '["/(?:WEB-DL|AMZN|DSNP|YTS|RARBG|EZTV)/i"]'
  REGEX_FILTER_ACCESS: "all"
  PORT: "3000"
```

**Critical:** WHITELISTED_REGEX_PATTERNS must be a JSON array string. Use single quotes in YAML to avoid shell escaping issues.

### Example 4: Deployment (excerpt - full structure)

[CITED: mcp-servers/proxmox-mcp.yaml pattern + STACK.md resource limits]

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: aiostreams
  namespace: aiostreams
spec:
  replicas: 1
  selector:
    matchLabels:
      app: aiostreams
  template:
    metadata:
      labels:
        app: aiostreams
    spec:
      containers:
        - name: aiostreams
          image: ghcr.io/viren070/aiostreams:v2.29.5
          imagePullPolicy: IfNotPresent
          ports:
            - containerPort: 3000
              name: http
          env:
            - name: BASE_URL
              value: "http://192.168.1.205:3000"
            - name: DATABASE_URI
              value: "sqlite://./data/db.sqlite"
          envFrom:
            - secretRef:
                name: aiostreams-secret  # Injects SECRET_KEY, FORCED_SERVICE_CREDENTIALS
            - configMapRef:
                name: aiostreams-config  # Injects WHITELISTED_REGEX_PATTERNS, PORT, REGEX_FILTER_ACCESS
          resources:
            requests:
              cpu: 100m
              memory: 128Mi
            limits:
              cpu: 500m
              memory: 256Mi
          livenessProbe:
            httpGet:
              path: /api/v1/status
              port: 3000
            initialDelaySeconds: 10
            periodSeconds: 10
            timeoutSeconds: 5
            failureThreshold: 3
          readinessProbe:
            httpGet:
              path: /api/v1/status
              port: 3000
            initialDelaySeconds: 5
            periodSeconds: 5
            timeoutSeconds: 3
            failureThreshold: 2
          volumeMounts:
            - name: data
              mountPath: /app/data
      volumes:
        - name: data
          persistentVolumeClaim:
            claimName: aiostreams-sqlite
      terminationGracePeriodSeconds: 30
```

### Example 5: PVC (excerpt - in deployment.yaml)

[CITED: REQUIREMENTS.md K8S-05 + k3s local-path storage]

```yaml
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: aiostreams-sqlite
  namespace: aiostreams
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: local-path
  resources:
    requests:
      storage: 10Gi
```

### Example 6: Service (excerpt - in deployment.yaml)

[CITED: mcp-servers/proxmox-mcp.yaml pattern + CONTEXT.md D-02]

```yaml
---
apiVersion: v1
kind: Service
metadata:
  name: aiostreams
  namespace: aiostreams
spec:
  type: LoadBalancer
  selector:
    app: aiostreams
  ports:
    - port: 3000
      targetPort: 3000
      protocol: TCP
  annotations:
    metallb.universe.tf/loadBalancerIPs: "192.168.1.205"
```

### Example 7: ArgoCD Application CR

[CITED: argocd/apps/mcp-servers.yaml template]

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: aiostreams
  namespace: argocd
spec:
  project: default
  source:
    repoURL: http://forgejo.local:3000/root/infra.git
    targetRevision: main
    path: kubernetes/aiostreams
  destination:
    server: https://kubernetes.default.svc
    namespace: aiostreams
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

---

## State of the Art

| Component | Old Approach | Current (This Phase) | When Changed | Impact |
|-----------|--------------|----------------------|--------------|--------|
| Secrets management | Manual Kubernetes Secret manifests (secrets in git) | ExternalSecret + OpenBao (secrets external, synced at deploy time) | Phase 1 / Phase 2 | No secrets in git; immutable, auditable credential rotation |
| Storage | emptyDir volumes (data lost on restart) | PVC with local-path storage (persistent across restarts) | Phase 2 | User config and cache survive pod restarts |
| Networking | ClusterIP + port-forward (manual, pod-dependent) | LoadBalancer with MetalLB IP pinning (stable, LAN-accessible) | Phase 2 | Stremio clients can reach service without manual routing |
| Health checking | No probes or TCP probes | HTTP probes to `/api/v1/status` | Phase 2 | Application-level health detection; catches hangs |
| Configuration | Hard-coded env in Deployment | ConfigMap + envFrom + Secret (separates config from spec) | Phase 2 | Config can evolve without pod restart (future capability) |

**Deprecated/outdated:**
- Storing secrets in git: never safe; even base64-encoded k8s Secrets in manifests are vulnerable. Use ExternalSecret instead.
- emptyDir for stateful workloads: data is ephemeral; lose everything on pod eviction. Use PVC instead.
- Manual provisioning of debrid credentials: error-prone, no audit trail. Use OpenBao + ExternalSecret instead.

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | kubectl (CLI) + curl (endpoint testing) |
| Config file | None — validation is operational checklist |
| Quick run command | `kubectl get externalsecrets -n aiostreams -o wide` |
| Full suite command | See Validation Checklist below |

### Phase Requirements → Validation Map

| Req ID | Behavior | Validation Step | Automated | Manual |
|--------|----------|-----------------|-----------|--------|
| K8S-01 | Namespace `aiostreams` exists and is Active | `kubectl get namespace aiostreams` | ✅ | — |
| K8S-02 | ArgoCD Application is synced and healthy | `argocd app get aiostreams` (should show `Synced: true, Health: Healthy`) | ✅ | ArgoCD UI |
| K8S-03 | Deployment pod running with correct image | `kubectl get deployment -n aiostreams aiostreams -o jsonpath='{.spec.template.spec.containers[0].image}'` should match v2.29.5 | ✅ | — |
| K8S-03 | Health probes succeed | `kubectl get pod -n aiostreams -o wide` (pod ready 1/1) | ✅ | — |
| K8S-04 | Service has LoadBalancer IP | `kubectl get svc -n aiostreams aiostreams` should show `EXTERNAL-IP: 192.168.1.205` | ✅ | — |
| K8S-04 | Service responds on port 3000 from LAN | `curl -s http://192.168.1.205:3000/api/v1/status` (from non-k8s LAN device) | ✅ | — |
| K8S-05 | PVC is bound and mounted | `kubectl get pvc -n aiostreams aiostreams-sqlite` (should be `Bound`) | ✅ | — |
| K8S-06 | ExternalSecret synced successfully | `kubectl get externalsecrets -n aiostreams aiostreams-secret -o wide` (should show `SYNC_STATUS: true`) | ✅ | — |
| K8S-06 | Secret contains correct keys | `kubectl get secret -n aiostreams aiostreams-secret -o jsonpath='{.data}' \| base64 -d` (should include SECRET_KEY and FORCED_SERVICE_CREDENTIALS) | Manual | ✅ |

### Validation Checklist (Wave 0 — Before Phase Execution Begins)

Wave 0 validation happens before any implementation tasks start. These are pre-flight checks to verify the research assumptions:

- [ ] **Phase 1 prerequisite met:** `bao policy read eso-policy` includes `path "secret/data/aiostreams/*"` with `read` capability
- [ ] **Phase 1 prerequisite met:** `bao kv get secret/aiostreams/production` returns a secret containing `SECRET_KEY` and `FORCED_SERVICE_CREDENTIALS`
- [ ] **ClusterSecretStore exists:** `kubectl get clustersecretstore openbao` (should exist from Phase 1)
- [ ] **ExternalSecret CRD installed:** `kubectl get crds | grep external-secrets` (ESO should be deployed)
- [ ] **local-path StorageClass exists:** `kubectl get storageclass local-path` (k3s default; should exist)
- [ ] **MetalLB pool includes 192.168.1.205:** Check MetalLB config (pool is 192.168.1.200-220)

### Validation Checklist (Per-Task Commit)

After each task is implemented and committed:

- [ ] **namespace.yaml:** `kubectl get namespace aiostreams` shows status `Active`
- [ ] **configmap.yaml:** `kubectl get configmap -n aiostreams aiostreams-config -o yaml` shows WHITELISTED_REGEX_PATTERNS as JSON array (validate syntax)
- [ ] **external-secret.yaml:** `kubectl get externalsecrets -n aiostreams` shows `SYNC_STATUS: true` (not `Failed`)
- [ ] **Secret created:** `kubectl get secret -n aiostreams aiostreams-secret` exists and contains `SECRET_KEY`, `FORCED_SERVICE_CREDENTIALS` keys
- [ ] **deployment.yaml:** `kubectl get deployment -n aiostreams aiostreams` shows `READY: 1/1`
- [ ] **PVC bound:** `kubectl get pvc -n aiostreams aiostreams-sqlite` shows status `Bound`
- [ ] **Service IP assigned:** `kubectl get svc -n aiostreams aiostreams` shows `EXTERNAL-IP: 192.168.1.205`
- [ ] **Pod health:** `kubectl get pods -n aiostreams aiostreams-<uid>` shows `READY: 1/1` and `STATUS: Running`
- [ ] **Logs clean:** `kubectl logs -n aiostreams deployment/aiostreams` shows no error messages (expect startup logs + server ready message)
- [ ] **Endpoint reachable:** `curl -s http://192.168.1.205:3000/api/v1/status | jq .` from a non-k8s LAN device (should return JSON status)

### Wave Gate

**Before marking Phase 2 complete:**

- [ ] All validation checklist items above passed
- [ ] ArgoCD Application synced and healthy: `argocd app sync aiostreams && argocd app wait aiostreams`
- [ ] Pod has been running for ≥ 2 minutes (probes should be stable)
- [ ] No pod restarts (check `RESTARTS` column in `kubectl get pods`)
- [ ] `/api/v1/status` endpoint returns HTTP 200 with valid JSON response

---

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control | Notes |
|---------------|---------|------------------|-------|
| V2 Authentication | No | — | AIOStreams UI has no authentication (ADDON_PASSWORD is optional); assumes intranet-only access |
| V3 Session Management | No | — | No user sessions managed by Kubernetes; AIOStreams handles internally |
| V4 Access Control | Partial | RBAC (namespaced RBAC for ESO + Deployment) | k8s RBAC restricts which workloads can read the aiostreams-secret; no external access control |
| V5 Input Validation | Yes | Application-level (AIOStreams validates regex patterns) | AIOStreams validates WHITELISTED_REGEX_PATTERNS format before use; invalid JSON rejected at startup |
| V6 Cryptography | Yes | OpenBao key derivation (SECRET_KEY → AES-256-GCM) | AIOStreams uses SECRET_KEY to derive encryption keys for user config storage; no custom crypto |
| V10 Malware | No | — | Container image from official ghcr.io registry; no custom code |

### Known Threat Patterns for AIOStreams on k3s

| Pattern | STRIDE Category | Standard Mitigation | Verification |
|---------|-----------------|---------------------|--------------|
| Real-Debrid API key exposed in logs or git | **Tampering** / **Information Disclosure** | ExternalSecret (credentials in OpenBao, not in git); no secrets in manifests; audit OpenBao access logs | `git log -p --all -S "apiKey"` (should find none) |
| ExternalSecret sync fails, pod crashes without secrets | **Availability** | Policy scoping (eso-policy must include `secret/data/aiostreams/*`); ExternalSecret status monitoring | `kubectl describe externalsecret aiostreams-secret` (should show `Sync Successful`) |
| Unauthorized pod reads Secret | **Information Disclosure** | k8s RBAC (only aiostreams Deployment can mount aiostreams-secret); namespace isolation | `kubectl auth can-i get secrets --as=system:serviceaccount:aiostreams:default` (no hardcoded access) |
| Stremio clients cannot reach service (denial of service) | **Availability** | MetalLB LoadBalancer pinned IP (stable); health probes (catch app hangs); PVC (persistence) | `curl http://192.168.1.205:3000/api/v1/status` reachable from LAN |
| User config lost due to SECRET_KEY rotation | **Availability** / **Data Loss** | Treat SECRET_KEY as immutable; document in runbook; audit logs on OpenBao | Rotation requires user reinstall (breaking change) |
| SQLite database corrupted or lost | **Availability** / **Data Loss** | PVC with local-path (persistent, backed by node filesystem); backup strategy deferred | `kubectl get pvc -n aiostreams` shows `Bound` and healthy mount |
| Regex pattern injection (malicious patterns in ConfigMap) | **Tampering** | ConfigMap is version-controlled (git audit trail); regex syntax validated on startup | Test pattern in AIOStreams UI before committing |
| Container escape (pod breakout) | **Elevation of Privilege** | Container runtime (containerd) security; no privileged mode; minimal base image | Not verified in this phase (k3s infra responsibility) |

**Intranet-only risk mitigation:** This deployment is LAN-only (MetalLB on internal network). Internet-facing deployment would require additional controls (TLS, authentication, rate limiting). This is documented as out-of-scope (REQUIREMENTS.md).

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong | Mitigation |
|---|-------|---------|---------------|-----------|
| A1 | `local-path` StorageClass exists in this k3s cluster and is named `local-path` | Validation Architecture | Pod cannot bind PVC; phase fails at provisioning stage | Verify with `kubectl get storageclass` before writing manifests |
| A2 | ExternalSecret CRD (`external-secrets.io/v1beta1`) is installed on the cluster | Validation Architecture | ExternalSecret CR creation fails; phase fails at manifest deployment | Verify with `kubectl get crds \| grep external-secrets` before execution |
| A3 | `ClusterSecretStore/openbao` exists and is correctly configured (from Phase 1) | Architecture Patterns Pattern 1 | ExternalSecret cannot authenticate to OpenBao; sync fails silently | Phase 1 is a prerequisite; verify with `kubectl get clustersecretstore openbao` |
| A4 | OpenBao `eso-policy` is extended to include `path "secret/data/aiostreams/*"` with `read` capability | Common Pitfalls Pitfall 2 | ExternalSecret fails with 403 Forbidden; pod crashes | Phase 1 is a prerequisite; verify with `bao policy read eso-policy` |
| A5 | MetalLB is installed and configured with a pool including 192.168.1.200-220 | Architecture Patterns Pattern 2 | Service LoadBalancer cannot assign IP; phase fails at provisioning | Verify with `kubectl get configmap -n metallb-system config` or similar |
| A6 | The ElfHosted WHITELISTED_REGEX_PATTERNS value in D-05 is `["/(WEB-DL|AMZN|DSNP|YTS|RARBG|EZTV)/i"]` and is current as of May 2026 | User Constraints D-05 | Regex patterns don't match current RD block list; filter doesn't work as intended | Research verified this pattern against .env.sample; but ElfHosted config may evolve. Recommend quarterly review per REQUIREMENTS.md RES-01 |
| A7 | `openssl rand -hex 32` generates a 64-character hex string suitable for AIOStreams SECRET_KEY | Architecture Patterns Pattern 1 | SECRET_KEY format mismatch; application fails to decrypt user configs | Verified in .env.sample; output is always 64 hex chars from this command |
| A8 | FORCED_SERVICE_CREDENTIALS format in OpenBao is exactly `realdebrid.apiKey=<key>` (not `token`, not underscore) | Code Examples Example 2 | Real-Debrid credentials silently ignored; no streams available | Verified in .env.sample and Pitfalls gotcha 2; format is serviceId.credentialId=value |

**Mitigation summary:** Most assumptions are verified or low-risk (Wave 0 checks catch them). A6 (ElfHosted pattern) is ASSUMED; recommend user confirmation during planning phase that the regex pattern matches their intended blocklist.

---

## Open Questions (RESOLVED)

1. **WHITELISTED_REGEX_PATTERNS Exact Value**
   - What we know: Initial value is `["/(WEB-DL|AMZN|DSNP|YTS|RARBG|EZTV)/i"]` (per CONTEXT.md D-05)
   - RESOLVED: Use `["/(WEB-DL|AMZN|DSNP|YTS|RARBG|EZTV)/i"]` as the initial ConfigMap value per CONTEXT.md D-05. ElfHosted docs do not explicitly document a specific value — the planner will bake in this value and the user can adjust post-deployment via ConfigMap edit + rollout restart (no redeployment required).

2. **ExternalSecret Refresh Interval**
   - What we know: `refreshInterval` is a required field; common values are `1h`, `10m`, `0s` (one-time sync)
   - RESOLVED: Use `refreshInterval: 1h`. SECRET_KEY is immutable per CLAUDE.md; FORCED_SERVICE_CREDENTIALS rarely changes. Hourly polling is sufficient and avoids unnecessary API calls to OpenBao.

3. **MetalLB IP 192.168.1.205 Availability**
   - What we know: CONTEXT.md lists IPs .200–.204 as assigned; .205 is the next sequential free IP
   - RESOLVED: Plan 03 Wave 2 Task 1 includes a pre-flight check (`kubectl get svc --all-namespaces -o wide | grep 192.168.1.205`) to verify the IP is unallocated before committing. If taken, executor will stop and report.

4. **SQLite Concurrency Under Load**
   - What we know: SQLite is adequate for single-user homelab; PITFALLS.md documents concurrency limitations
   - RESOLVED: Acceptable risk for single-user homelab use case. No action required in Phase 2. Defer to Phase 3 documentation if monitoring reveals locking issues.

5. **Regex Pattern YAML Escaping**
   - What we know: WHITELISTED_REGEX_PATTERNS must be a JSON array string; forward slashes and backslashes must be escaped properly in YAML
   - RESOLVED: Use single-quoted YAML scalar (`'["/(WEB-DL|AMZN|DSNP|YTS|RARBG|EZTV)/i"]'`). Single quotes in YAML require no escape sequences and safely contain forward slashes and pipe characters. Validated against PITFALLS.md guidance.

---

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Kubernetes cluster (k3s) | Deployment, Services, PVC, Namespace | ✓ | 1.28+ (assumed) | None — this phase depends on k3s |
| ExternalSecret CRD | ExternalSecret manifests | ✓ | v1beta1 (assumed from Phase 1) | Manual Kubernetes Secret creation (not recommended; secrets in git) |
| ClusterSecretStore/openbao | ExternalSecret sync | ✓ | Deployed in Phase 1 | None — prerequisite from Phase 1 |
| OpenBao | Secret storage backend | ✓ | http://192.168.1.210:8200 | None — prerequisite from Phase 1 |
| MetalLB | LoadBalancer Service IP assignment | ✓ | Deployed in homelab | ClusterIP + port-forward (not ideal; less accessible) |
| local-path StorageClass | PVC provisioning | ✓ | k3s built-in | NFS or other persistent storage (requires additional provisioner) |
| AIOStreams container image | Deployment container | ✓ | ghcr.io/viren070/aiostreams:v2.29.5 | Docker Hub (less preferred; use ghcr.io) |
| git (Forgejo) | ArgoCD source repository | ✓ | http://forgejo.local:3000/root/infra.git | Manual kubectl apply (breaks GitOps) |
| ArgoCD | Automated Kubernetes syncing | ✓ | Deployed in homelab | Manual kubectl apply (not recommended) |

**Missing dependencies with no fallback:** None. All required infrastructure is from Phase 1 or existing homelab setup.

**Missing dependencies with fallback:** None that would affect Phase 2 execution.

---

## Sources

### Primary (HIGH confidence)
- [AIOStreams .env.sample](https://github.com/Viren070/AIOStreams/blob/main/.env.sample) — environment variables, FORCED_SERVICE_CREDENTIALS format, WHITELISTED_REGEX_PATTERNS structure
- [External Secrets Operator API Spec](https://external-secrets.io/latest/api/spec/) — ExternalSecret CRD structure, data/secretKey/remoteRef fields, refreshInterval
- [External Secrets Operator Vault Provider](https://external-secrets.io/latest/provider/hashicorp-vault/) — KV v2 path format (`secret/data/` prefix handling)
- [AIOStreams Setup Guide](https://guides.viren070.me/stremio/addons/aiostreams/setup) — health check endpoint, deployment patterns
- [AIOStreams GitHub Releases](https://github.com/Viren070/AIOStreams/releases) — v2.29.5 current stable (May 2026)
- [Kubernetes PersistentVolumeClaim Docs](https://kubernetes.io/docs/concepts/storage/persistent-volumes/) — PVC spec, local-path storage
- [k3s Storage Documentation](https://docs.k3s.io/storage) — local-path StorageClass, default configuration
- [ArgoCD Sync Waves](https://argo-cd.readthedocs.io/en/latest/user-guide/sync-options/) — resource ordering via annotations

### Secondary (MEDIUM confidence)
- [ElfHosted AIOStreams Documentation](https://docs.elfhosted.com/app/aiostreams/) — configuration options (note: does not list WHITELISTED_REGEX_PATTERNS explicitly; assumed pattern from .env.sample is canonical)
- [AIOStreams GitHub Wiki - Configuration](https://github.com/Viren070/AIOStreams/wiki/Configuration) — feature flags, credential management
- [Hashicorp Vault KV v2 API](https://developer.hashicorp.com/vault/api-docs/secret/kv-v2) — path format, metadata handling

### Tertiary (Research artifacts)
- `.planning/research/PITFALLS.md` — Phase-specific gotchas and risk patterns (HIGH confidence, verified in prior phase)
- `.planning/research/STACK.md` — verified environment variables, resource limits (HIGH confidence)
- `.planning/research/ARCHITECTURE.md` — reference patterns, anti-patterns (HIGH confidence)
- `kubernetes/external-secrets/cluster-secret-store.yaml` — existing ClusterSecretStore config (verified from codebase)
- `argocd/apps/mcp-servers.yaml` — ArgoCD Application template (verified from codebase)
- `kubernetes/mcp-servers/proxmox-mcp.yaml` — Deployment + Service pattern (verified from codebase)

---

## Metadata

**Confidence breakdown:**
- **Standard stack:** HIGH — AIOStreams version pinned, image verified, storage class confirmed (k3s default)
- **Architecture patterns:** HIGH — ExternalSecret CRD, LoadBalancer Service, PVC patterns all verified against official docs
- **Pitfalls:** HIGH — PITFALLS.md sourced from prior research; critical gotchas verified (SECRET_KEY immutability, ESO policy scope, regex format)
- **ExternalSecret details:** HIGH — CRD structure verified against external-secrets.io official API spec
- **ElfHosted baseline:** MEDIUM → ASSUMED — .env.sample shows the pattern, but ElfHosted docs don't explicitly list their WHITELISTED_REGEX_PATTERNS value. User should confirm before deployment.

**Research date:** 2026-05-12
**Valid until:** 2026-05-19 (7 days — AIOStreams releases rapidly; check for v2.30 or later)

---

*Phase 2 Research complete. Ready for planning.*
