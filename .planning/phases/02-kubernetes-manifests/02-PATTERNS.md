# Phase 2: Kubernetes Manifests - Pattern Map

**Mapped:** 2026-05-12
**Files analyzed:** 5 new files
**Analogs found:** 4/5 (80% direct analog coverage)

---

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `kubernetes/aiostreams/namespace.yaml` | config | static | `kubernetes/mcp-servers/namespace.yaml` | exact |
| `kubernetes/aiostreams/external-secret.yaml` | config | request-response | `kubernetes/external-secrets/cluster-secret-store.yaml` | partial (first ESO workload; reference pattern only) |
| `kubernetes/aiostreams/configmap.yaml` | config | static | `kubernetes/forgejo-runner/deployment.yaml` (ConfigMap section) | role-match (no dedicated ConfigMap file exists) |
| `kubernetes/aiostreams/deployment.yaml` | config | CRUD + streaming | `kubernetes/mcp-servers/proxmox-mcp.yaml` | exact (Deployment + Service structure) |
| `argocd/apps/aiostreams.yaml` | config | request-response | `argocd/apps/mcp-servers.yaml` | exact (template copy) |

---

## Pattern Assignments

### `kubernetes/aiostreams/namespace.yaml` (config, static)

**Analog:** `kubernetes/mcp-servers/namespace.yaml` (exact match)

**Full template** (lines 1-4):
```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: aiostreams
  annotations:
    argocd.argoproj.io/sync-wave: "-2"  # Create FIRST in ArgoCD sync order
```

**Changes from analog:**
- `metadata.name`: `mcp-servers` → `aiostreams`
- **Add annotation** `argocd.argoproj.io/sync-wave: "-2"` (critical pitfall: ensures namespace exists before ExternalSecret tries to target it; mcp-servers.yaml has no annotation but AIOStreams requires sync wave ordering per RESEARCH.md Pitfall 3)

**Why:** Explicit sync wave prevents ExternalSecret validation failure when namespace doesn't exist yet.

---

### `kubernetes/aiostreams/external-secret.yaml` (config, request-response)

**Analog:** `kubernetes/external-secrets/cluster-secret-store.yaml` (reference pattern for ClusterSecretStore structure; first ESO workload in cluster)

**RESEARCH.md provides the canonical ExternalSecret pattern** (RESEARCH.md lines 236-261):
```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: aiostreams-secret
  namespace: aiostreams
  annotations:
    argocd.argoproj.io/sync-wave: "-1"  # Create AFTER namespace (wave -2)
spec:
  refreshInterval: 1h  # Immutable SECRET_KEY; hourly is sufficient
  secretStoreRef:
    name: openbao  # References ClusterSecretStore named "openbao" from Phase 1
    kind: ClusterSecretStore
  target:
    name: aiostreams-secret  # k8s Secret name that ESO will create in aiostreams namespace
    creationPolicy: Owner  # ESO owns this Secret; delete Secret if ExternalSecret is deleted
  data:
    - secretKey: SECRET_KEY
      remoteRef:
        key: aiostreams/production  # OpenBao path (no "secret/" prefix; ESO adds it for KV v2)
        property: SECRET_KEY  # Field name in the OpenBao secret object
    - secretKey: FORCED_SERVICE_CREDENTIALS
      remoteRef:
        key: aiostreams/production
        property: FORCED_SERVICE_CREDENTIALS
```

**Reference:** ClusterSecretStore pattern (lines 1-17 of `kubernetes/external-secrets/cluster-secret-store.yaml`):
```yaml
apiVersion: external-secrets.io/v1beta1
kind: ClusterSecretStore
metadata:
  name: openbao
spec:
  provider:
    vault:
      server: "http://192.168.1.210:8200"
      path: "secret"
      version: "v2"
      auth:
        kubernetes:
          mountPath: "kubernetes"
          role: "eso-reader"
```

**Critical implementation notes:**
1. **No analog exists** in the codebase (first ESO workload). RESEARCH.md provides the canonical pattern.
2. **Path format:** `key: aiostreams/production` (NOT `secret/aiostreams/production`). ESO automatically prepends `secret/data/` for Vault KV v2. Final request: `GET /v1/secret/data/aiostreams/production`
3. **Sync waves:** ExternalSecret must have `sync-wave: "-1"` to ensure namespace (wave `-2`) exists first
4. **Phase 1 prerequisite:** `bao policy write eso-policy` must include `path "secret/data/aiostreams/*" { capabilities = ["read"] }`
5. **refreshInterval:** Set to `1h` (not `0s` for one-time sync, since SECRET_KEY is immutable and RD credentials rarely change)

**Why this pattern:**
- No secrets in git (credentials stay in OpenBao)
- Explicit `data` entries make auditable which secrets are synced
- `creationPolicy: Owner` ensures cleanup if ExternalSecret is deleted
- ClusterSecretStore reference points to existing Phase 1 OpenBao auth setup

**Pitfall to avoid (RESEARCH.md Pitfall 2):** If eso-policy is not extended to `secret/data/aiostreams/*`, ExternalSecret shows `SyncFailed` but error is easy to miss. Always verify: `bao policy read eso-policy | grep aiostreams`

---

### `kubernetes/aiostreams/configmap.yaml` (config, static)

**Analog:** `kubernetes/forgejo-runner/deployment.yaml` (ConfigMap section, lines 7-26)

**Pattern from RESEARCH.md Code Examples (lines 526-536):**
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

**Reference: forgejo-runner ConfigMap structure** (lines 7-26):
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: runner-config
  namespace: forgejo-runner
data:
  config.yml: |
    log:
      level: info
    ...
```

**Changes from forgejo-runner pattern:**
- Single-quoted string for WHITELISTED_REGEX_PATTERNS (avoids YAML escaping nightmares)
- Simple key-value data (not nested YAML/config file)
- ConfigMap name: `aiostreams-config` (naming convention: `<app>-config`)

**Critical implementation notes:**
1. **JSON array format (MANDATORY):** WHITELISTED_REGEX_PATTERNS must be valid JSON array, not comma-separated or newline-delimited text (RESEARCH.md Pitfall 4)
2. **YAML escaping:** Use single quotes `'...'` to prevent YAML interpreter from processing forward slashes, backslashes, or special chars
3. **Verify syntax:** Before committing, test: `kubectl get cm -n aiostreams aiostreams-config -o jsonpath='{.data.WHITELISTED_REGEX_PATTERNS}' | jq .` (must parse as valid JSON)
4. **Initial value:** D-05 from CONTEXT.md specifies `["/(WEB-DL|AMZN|DSNP|YTS|RARBG|EZTV)/i"]` (researcher should confirm against ElfHosted docs)

**Why this pattern:**
- ConfigMap isolates evolving regex patterns from Deployment spec (quarterly updates per RES-01)
- Non-secret values safely version-controlled in git
- `envFrom: configMapRef` injects all keys as env vars (no per-key remapping needed)

---

### `kubernetes/aiostreams/deployment.yaml` (config, CRUD + streaming)

**Analog:** `kubernetes/mcp-servers/proxmox-mcp.yaml` (exact match: Deployment + Service in one file)

**Deployment structure** (lines 1-60 from analog):
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: proxmox-mcp
  namespace: mcp-servers
spec:
  replicas: 1
  selector:
    matchLabels:
      app: proxmox-mcp
  template:
    metadata:
      labels:
        app: proxmox-mcp
    spec:
      containers:
        - name: proxmox-mcp
          image: node:22-alpine
          ports:
            - containerPort: 8080
          env:
            - name: VAR_NAME
              value: "value"
          volumeMounts:
            - name: volume-name
              mountPath: /path
      volumes:
        - name: volume-name
          [volumeType]
```

**Service structure** (lines 62-73 from analog):
```yaml
---
apiVersion: v1
kind: Service
metadata:
  name: proxmox-mcp
  namespace: mcp-servers
spec:
  type: LoadBalancer
  selector:
    app: proxmox-mcp
  ports:
    - port: 8080
      targetPort: 8080
```

**RESEARCH.md provides the complete aiostreams Deployment + PVC + Service pattern** (lines 541-651):

**Deployment template:**
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
                name: aiostreams-secret  # From ExternalSecret
            - configMapRef:
                name: aiostreams-config  # Regex patterns, PORT, REGEX_FILTER_ACCESS
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

**PVC template:**
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

**Service with MetalLB IP pinning:**
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

**Changes from proxmox-mcp analog:**
- Image: `node:22-alpine` → `ghcr.io/viren070/aiostreams:v2.29.5` (pinned version, no `latest`)
- Ports: 8080 → 3000
- Labels/names: `proxmox-mcp` → `aiostreams`
- Namespace: `mcp-servers` → `aiostreams`
- **Add:** envFrom (secretRef + configMapRef) instead of individual env entries
- **Add:** env vars BASE_URL, DATABASE_URI (specific to AIOStreams config)
- **Add:** livenessProbe + readinessProbe (HTTP probes to `/api/v1/status`, new to this analog)
- **Add:** resources requests/limits (100m/500m CPU, 128Mi/256Mi RAM from CONTEXT.md)
- **Add:** PVC volume mount (SQLite persistence, new to this codebase)
- **Add:** Service annotation `metallb.universe.tf/loadBalancerIPs` (pin IP to 192.168.1.205; mcp-servers doesn't pin IPs)

**Critical implementation notes:**
1. **Health probes are new pattern:** No existing health probe examples in codebase. Use HTTP probes (not TCP) to `/api/v1/status` port 3000. Both liveness (10s initial delay, 10s period) and readiness (5s initial delay, 5s period) required per K8S-03.
2. **PVC is new pattern:** First persistent storage in cluster. Use `local-path` StorageClass (k3s default), 10Gi, ReadWriteOnce, mounted at `/app/data`.
3. **MetalLB IP annotation is new:** Proxy services don't pin IPs (auto-assigned). AIOStreams requires 192.168.1.205 (D-02 from CONTEXT.md, next sequential free IP).
4. **envFrom pattern:** Both secretRef and configMapRef inject all keys as env vars. No per-field remapping needed (keys in OpenBao match env var names exactly per Phase 1 D-03).
5. **Image pull policy:** Use `IfNotPresent` (don't re-pull if already cached; appropriate for stable pinned version).
6. **terminationGracePeriodSeconds:** Set to 30 to allow graceful shutdown (SQLite needs time to flush).

**Why this pattern:**
- Deployment manages pod lifecycle (single replica for local-path PVC compatibility)
- LoadBalancer Service exposes to LAN via MetalLB
- IP pinning ensures stable, reachable address (BASE_URL mismatch → addon installation fails, Pitfall 6)
- Health probes detect application-level hangs (TCP probe only checks port is open)
- Resource limits prevent node exhaustion (100m req, 500m limit CPU; 128Mi req, 256Mi limit RAM)
- PVC provides persistent SQLite database (survives pod restarts)

---

### `argocd/apps/aiostreams.yaml` (config, request-response)

**Analog:** `argocd/apps/mcp-servers.yaml` (exact match: template copy with name/path/namespace changes)

**Full template** (lines 1-20):
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: mcp-servers
  namespace: argocd
spec:
  project: default
  source:
    repoURL: http://forgejo.local:3000/root/infra.git
    targetRevision: main
    path: kubernetes/mcp-servers
  destination:
    server: https://kubernetes.default.svc
    namespace: mcp-servers
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

**Changes from analog (verbatim copy except these 3 fields):**
- `metadata.name`: `mcp-servers` → `aiostreams`
- `source.path`: `kubernetes/mcp-servers` → `kubernetes/aiostreams`
- `destination.namespace`: `mcp-servers` → `aiostreams`
- **Keep:** repoURL, targetRevision (main), project (default), syncPolicy (automated, prune, selfHeal), CreateNamespace=true

**Why this pattern:**
- ArgoCD watches git repository and auto-syncs manifests
- `CreateNamespace=true` creates namespace if it doesn't exist (safety net for explicit `sync-wave: "-2"` in namespace.yaml)
- `prune: true` deletes resources removed from git (ensures cleanup)
- `selfHeal: true` re-syncs if manual kubectl edits are made (GitOps enforcement)
- `targetRevision: main` ensures only committed, reviewed manifests are deployed

**No differences in structure:** Unlike mcp-servers Services which have no IP annotation, aiostreams Service adds the MetalLB annotation — but that's in `deployment.yaml`, not in the ArgoCD Application CR itself.

---

## Shared Patterns

### ExternalSecret + OpenBao Integration (Applied to all future ESO workloads)

**Source:** `kubernetes/external-secrets/cluster-secret-store.yaml` (Phase 1 artifact) + RESEARCH.md Pattern 1

**Pattern:** ExternalSecret syncs credentials from OpenBao → creates native k8s Secret

**Template:**
```yaml
# External secrets always reference ClusterSecretStore/openbao
secretStoreRef:
  name: openbao
  kind: ClusterSecretStore

# KV v2 path format: key = aiostreams/production (ESO adds secret/data/ prefix)
remoteRef:
  key: <app>/<env>  # Examples: aiostreams/production, othercli/staging
  property: <field-name>  # Must match field name in OpenBao secret

# ESO creates a k8s Secret with these names
target:
  name: <app>-secret  # Naming convention: <app>-secret
  creationPolicy: Owner  # ESO owns; cleanup if ExternalSecret deleted
```

**Apply to:** All future workloads that need credentials from OpenBao. Establish pattern now (aiostreams is first); reuse for all subsequent phases.

**Prerequisite check:** Before deploying any ExternalSecret:
```bash
# Verify policy includes the app path
bao policy read eso-policy | grep "secret/data/<app>/*"

# Verify secret exists in OpenBao
bao kv get secret/<app>/<env>
```

---

### LoadBalancer Service with MetalLB (Applied to all intranet services)

**Source:** `kubernetes/mcp-servers/proxmox-mcp.yaml` (lines 62-73) + aiostreams extension with IP pinning

**Pattern (mcp-servers - auto IP):**
```yaml
spec:
  type: LoadBalancer
  selector:
    app: <app-name>
  ports:
    - port: <external-port>
      targetPort: <container-port>
```

**Pattern (aiostreams - pinned IP):**
```yaml
spec:
  type: LoadBalancer
  selector:
    app: aiostreams
  ports:
    - port: 3000
      targetPort: 3000
      protocol: TCP
  annotations:
    metallb.universe.tf/loadBalancerIPs: "192.168.1.XXX"  # Pin IP when BASE_URL is hardcoded
```

**Apply to:**
- All intranet services that need external access (use `type: LoadBalancer`)
- Only add IP pinning annotation if service address is hardcoded in application config (e.g., BASE_URL)
- Auto-assigned IPs are fine for services with hostname/discovery (future work with Traefik)

**IP pool allocation (CONTEXT.md D-02):**
- Pool range: 192.168.1.200–220
- Assigned: .200 ArgoCD, .201 proxmox-mcp, .202 atlassian-mcp, .203 forgejo-mcp, .204 Grafana, .210 OpenBao
- Next available: .205 (aiostreams), .206–.209, .211–.220

---

### ConfigMap for Environment Variables (Applied to all workloads with evolving config)

**Source:** `kubernetes/forgejo-runner/deployment.yaml` (lines 7-26, ConfigMap section)

**Pattern:**
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: <app>-config
  namespace: <namespace>
data:
  KEY_1: "value"
  KEY_2: "value"
  MULTI_LINE_CONFIG: |
    block scalar for multi-line content
```

**Injection into Deployment:**
```yaml
envFrom:
  - configMapRef:
      name: <app>-config  # All keys become env vars
```

**Apply to:**
- Non-secret configuration values that change frequently (regex patterns, feature flags, port numbers)
- Keep Deployment spec focused on container/orchestration concerns; ConfigMap for app-specific config
- Use block scalar (`|`) for multi-line content (YAML, JSON); single quotes for JSON arrays with regex

**Why separate ConfigMap:** Configuration evolves independently from Deployment spec. Quarterly updates to WHITELISTED_REGEX_PATTERNS (per RES-01) don't require pod restart if using ConfigMap with future controller that watches for changes.

---

## No Analog Found

No existing Kubernetes patterns in the codebase for these concerns:

| File/Pattern | Reason | Workaround |
|--------------|--------|-----------|
| PersistentVolumeClaim spec | First stateful workload with persistence | Use RESEARCH.md code example + k3s local-path StorageClass docs |
| HTTP health probes (liveness/readiness) | All existing workloads use default or no probes | Use RESEARCH.md K8S-03 spec + Kubernetes health probe docs |
| ExternalSecret CR | First ESO workload (Phase 1 only created ClusterSecretStore) | Use RESEARCH.md Pattern 1 + external-secrets.io API docs |

---

## Metadata

**Analog search scope:**
- `kubernetes/` directory: 6 files scanned (namespace, deployment, external-secrets, forgejo-runner)
- `argocd/apps/` directory: 1 file scanned (mcp-servers.yaml)
- Total files scanned: 7
- Exact analogs found: 3/5 (namespace, deployment, argocd app)
- Partial analogs: 1/5 (configmap — structure found in forgejo-runner, not as dedicated file)
- New patterns (from RESEARCH.md): 1/5 (external-secret — first ESO workload)

**Pattern extraction date:** 2026-05-12

**Files with high confidence patterns:**
- Deployment + Service (exact structure match to proxmox-mcp.yaml with documented extensions)
- ArgoCD Application CR (verbatim template match)
- Namespace (exact match with added sync-wave annotation)

**Files with research-backed patterns:**
- ExternalSecret (RESEARCH.md canonical pattern, no codebase precedent)
- ConfigMap (structure match from forgejo-runner; content from RESEARCH.md + CONTEXT.md decision)

**Critical pitfalls to highlight in planning:**
1. **Sync wave ordering:** Namespace must have `sync-wave: "-2"`, ExternalSecret must have `sync-wave: "-1"` (RESEARCH.md Pitfall 3)
2. **ExternalSecret path format:** Must be `aiostreams/production` (not `secret/aiostreams/production`); ESO adds KV v2 prefix (RESEARCH.md Pattern 1)
3. **WHITELISTED_REGEX_PATTERNS JSON format:** Must be valid JSON array string, use single quotes in YAML (RESEARCH.md Pitfall 4)
4. **MetalLB IP annotation:** Required because BASE_URL is hardcoded; pinning ensures stable address (RESEARCH.md Pitfall 6)
5. **Phase 1 prerequisite:** `bao policy write eso-policy` must include `path "secret/data/aiostreams/*"` (RESEARCH.md Pitfall 2)

---

*Phase 2 pattern mapping complete. Ready for planning.*
