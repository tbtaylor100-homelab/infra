# Architecture Patterns: AIOStreams on k3s

**Domain:** Kubernetes workload for Stremio filtering proxy
**Researched:** 2026-05-11
**Confidence:** HIGH

## Recommended Architecture

AIOStreams as a single-replica Kubernetes Deployment with persistent SQLite storage, secrets synced from OpenBao via External Secrets Operator, and network exposure via MetalLB LoadBalancer Service. All resources managed by ArgoCD following the existing mcp-servers pattern.

```
┌─ ArgoCD Application ──────────────────────────────────────────┐
│  app: aiostreams                                               │
│  source: kubernetes/aiostreams (git)                          │
├──────────────────────────────────────────────────────────────┤
│  ┌─ Namespace: aiostreams ────────────────────────────────┐   │
│  │                                                         │   │
│  │  ┌─ Deployment: aiostreams ──────────────────────┐    │   │
│  │  │  replicas: 1                                   │    │   │
│  │  │  container: ghcr.io/viren070/aiostreams       │    │   │
│  │  │  port: 3000                                    │    │   │
│  │  │  ├─ ExternalSecret vol-mount → SQLite PVC     │    │   │
│  │  │  ├─ Secret vol-mount (keys from OpenBao)      │    │   │
│  │  │  └─ Env vars from Secret + ConfigMap          │    │   │
│  │  │                                                │    │   │
│  │  │  ┌─ PVC: aiostreams-data ─────────────────┐   │    │   │
│  │  │  │ size: 10Gi                              │   │    │   │
│  │  │  │ storageClass: local-path (k3s default) │   │    │   │
│  │  │  │ mountPath: /app/data                    │   │    │   │
│  │  │  └─────────────────────────────────────────┘   │    │   │
│  │  └─────────────────────────────────────────────────┘    │   │
│  │                                                         │   │
│  │  ┌─ ExternalSecret: aiostreams-secret ────────────┐    │   │
│  │  │ pulls from ClusterSecretStore/openbao         │    │   │
│  │  │ source: secret/aiostreams/production          │    │   │
│  │  │ creates: Secret/aiostreams-secret in NS       │    │   │
│  │  └─────────────────────────────────────────────────┘    │   │
│  │                                                         │   │
│  │  ┌─ Service: aiostreams ─────────────────────────┐    │   │
│  │  │ type: LoadBalancer                            │    │   │
│  │  │ port: 3000 → targetPort 3000                  │    │   │
│  │  │ exposed to MetalLB on intranet                │    │   │
│  │  └─────────────────────────────────────────────────┘    │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                  │
│  External Dependencies:                                         │
│  └─ OpenBao at http://192.168.1.210:8200                      │
│     └─ secret/data/aiostreams/production (v2 KV)              │
│        ├─ real_debrid_api_key                                 │
│        └─ secret_key (or fetch from .env.sample)              │
└──────────────────────────────────────────────────────────────┘
```

## Resource Inventory

### 1. Namespace
Create `aiostreams` namespace to isolate from mcp-servers and other workloads.

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: aiostreams
```

**Why separate namespace:** Follows k8s best practice of workload isolation. ArgoCD will create it automatically with `CreateNamespace=true`.

### 2. Deployment
Single-replica Deployment for AIOStreams container.

**Container spec:**
- Image: `ghcr.io/viren070/aiostreams:latest` (or pinned version)
- Port: 3000 (AIOStreams default from env var `PORT`)
- Resources: No resource limits initially (can add if CPU/memory issues arise)

**Volume mounts:**
1. PVC mount at `/app/data` for SQLite database (`db.sqlite`)
2. Secret mount for credentials from OpenBao

**Environment variables:**
- Required: `SECRET_KEY` (64-char hex), `BASE_URL`, `DATABASE_URI`
- From Secret: `FORCED_SERVICE_CREDENTIALS` (Real-Debrid API key)
- From ConfigMap: `WHITELISTED_REGEX_PATTERNS`, `REGEX_FILTER_ACCESS`, `PORT`

### 3. PersistentVolumeClaim (PVC)
Local-path backed storage for SQLite database.

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: aiostreams-data
  namespace: aiostreams
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: local-path
  resources:
    requests:
      storage: 10Gi
```

**Why local-path:** k3s default, sufficient for single-user SQLite, minimal operational complexity.

**Why 10Gi:** Conservative estimate. SQLite on a single-user Stremio instance with filtered streams typically uses <100MB. 10Gi allows for growth, debugging, and potential future features.

**mountPath:** `/app/data` — AIOStreams stores `db.sqlite` here (from `DATABASE_URI=sqlite://./data/db.sqlite`).

### 4. ExternalSecret
Syncs secrets from OpenBao to Kubernetes Secret.

```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: aiostreams-secret
  namespace: aiostreams
spec:
  secretStoreRef:
    name: openbao
    kind: ClusterSecretStore
  target:
    name: aiostreams-secret
    creationPolicy: Owner
  data:
    - secretKey: real_debrid_api_key
      remoteRef:
        key: aiostreams/production
        property: real_debrid_api_key
    - secretKey: secret_key
      remoteRef:
        key: aiostreams/production
        property: secret_key
```

**Why `data` (individual keys):** Explicit, auditable sync. Only required secrets are pulled. If future config adds more keys, they're listed here.

**Why not `dataFrom`:** Less ideal for AIOStreams because credentials are sensitive. Explicit `data` entries make it clear which secrets are in use.

**Path format:** `aiostreams/production` (ESO handles `/data/` prefix for Vault v2 KV automatically).

**Property field:** Used to extract specific keys from the Vault secret object.

### 5. Service
LoadBalancer to expose AIOStreams on intranet.

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
```

**Port 3000:** AIOStreams default (configurable via `PORT` env var, but 3000 is standard).

**LoadBalancer:** MetalLB will assign an intranet IP. Clients (Stremio instances) connect to this LoadBalancer IP:3000.

### 6. ConfigMap (Optional)
Non-secret configuration that can be version-controlled.

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: aiostreams-config
  namespace: aiostreams
data:
  WHITELISTED_REGEX_PATTERNS: |
    WEB-DL
    AMZN
    DSNP
    YTS
    RARBG
    EZTV
  REGEX_FILTER_ACCESS: "all"
  PORT: "3000"
```

**Use case:** Regex patterns and feature toggles that change frequently and don't contain secrets.

---

## Manifest Structure

### File Layout
```
kubernetes/aiostreams/
├── namespace.yaml           # Namespace: aiostreams
├── deployment.yaml          # Deployment + PVC + Service
├── externalsecret.yaml      # ExternalSecret + target Secret
└── configmap.yaml           # ConfigMap for regex patterns
```

### ArgoCD Application
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

**Deployment strategy:** ArgoCD auto-syncs on git push. No manual `kubectl apply`.

---

## PVC Strategy

### Storage Class: local-path
- **Built-in to k3s:** No additional provisioners needed
- **Data persistence:** Stored on node's filesystem (survives pod restart)
- **Location:** `/var/lib/rancher/k3s/storage/` (k3s host directory)
- **Node affinity:** PVC is pinned to the node where the pod first schedules (implicit in local-path)

### PVC Size: 10Gi
- **Rationale:** SQLite on a single-user instance is compact. Overhead for future features.
- **Monitoring:** Add alerting if usage exceeds 8Gi.

### Backup Considerations
- **Not included in this phase:** Local-path is ephemeral with respect to node replacement
- **Future enhancement:** Consider backing up `/var/lib/rancher/k3s/storage/aiostreams-data-<uid>` to external storage (e.g., NFS, S3)

---

## ExternalSecret Pattern

### ClusterSecretStore Reference
Uses existing `openbao` ClusterSecretStore (defined in `kubernetes/external-secrets/cluster-secret-store.yaml`):
- **Provider:** Vault-compatible (OpenBao at `http://192.168.1.210:8200`)
- **Auth:** Kubernetes service account (`external-secrets` SA in `external-secrets` NS)
- **Mount path:** `kubernetes`
- **Vault version:** `v2` (automatic `/data/` handling)

### Secret Structure in OpenBao
Path: `secret/data/aiostreams/production` (v2 KV structure)

**Keys to store:**
```json
{
  "real_debrid_api_key": "your_rd_api_key_here",
  "secret_key": "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"
}
```

**How to populate:**
1. Generate `secret_key` (64-char hex):
   ```bash
   openssl rand -hex 32
   ```
2. Add Real-Debrid API key from your RD account.
3. Write to OpenBao:
   ```bash
   vault write secret/aiostreams/production \
     real_debrid_api_key="YOUR_KEY" \
     secret_key="YOUR_64_CHAR_HEX"
   ```

### Sync Method: data (Individual Keys)
**Why not `dataFrom`:**
- Explicit specification of sensitive keys
- Clear audit trail (what secrets are in use)
- Safer for auditing and compliance

**Alternative pattern (if needed):** Use `dataFrom.extract` to pull all keys at once:
```yaml
dataFrom:
  - extract:
      key: aiostreams/production
```
But individual `data` entries are recommended for AIOStreams.

### ESO Policy Extension
**Prerequisite:** OpenBao Kubernetes auth role `eso-reader` must be extended to include `secret/data/aiostreams/*`.

Current scope: `secret/data/homelab/ci`

**Required change:**
```hcl
# In OpenBao Kubernetes auth backend
path "secret/data/aiostreams/*" {
  capabilities = ["read", "list"]
}
```

---

## Service Exposure

### Port Configuration
- **Container port:** 3000 (set via `PORT=3000` env var)
- **Service port:** 3000 (no translation needed)
- **LoadBalancer IP:** Assigned by MetalLB from intranet pool (e.g., `192.168.1.x`)

### Access Pattern
1. Stremio client on LAN resolves AIOStreams LoadBalancer IP (e.g., via `/etc/hosts` or local DNS)
2. Client connects to `http://<lb-ip>:3000`
3. AIOStreams advertises itself via `BASE_URL` env var (set to the LoadBalancer IP or resolvable hostname)

### MetalLB Configuration (Out of Scope for This Phase)
Assuming MetalLB is already installed and configured (existing infrastructure). AIOStreams Service will automatically get an intranet LoadBalancer IP.

---

## Build & Deployment Order

### Phase Sequence
1. **OpenBao Setup** — Write secrets to `secret/aiostreams/production`
2. **Extend ESO Policy** — Add `secret/data/aiostreams/*` to `eso-reader` Kubernetes auth role
3. **Create Manifests** — Write YAML files to `kubernetes/aiostreams/`
4. **Create ArgoCD App** — Add Application CR to `argocd/apps/aiostreams.yaml`
5. **Git Push** — Commit and push to `http://forgejo.local:3000/root/infra.git`
6. **ArgoCD Sync** — ArgoCD auto-syncs (or manually trigger via ArgoCD UI)
7. **Validate** — Check pod logs, verify PVC mount, test service connectivity

### Validation Checklist
- [ ] Namespace created
- [ ] PVC bound (check `kubectl get pvc -n aiostreams`)
- [ ] ExternalSecret synced (check `kubectl get externalsecret -n aiostreams`)
- [ ] Secret created with real_debrid_api_key and secret_key
- [ ] Deployment pod running (check `kubectl get pods -n aiostreams`)
- [ ] Service assigned LoadBalancer IP (check `kubectl get svc -n aiostreams`)
- [ ] Container logs show successful startup (check `kubectl logs -n aiostreams`)
- [ ] AIOStreams web UI accessible at `http://<lb-ip>:3000`

---

## Anti-Patterns to Avoid

### ❌ Anti-Pattern 1: Hardcoding Secrets in Manifests
**What goes wrong:** Credentials leaked in git history.
**Instead:** Use ExternalSecret to sync from OpenBao (already recommended).

### ❌ Anti-Pattern 2: Using emptyDir for Database
**What goes wrong:** Database lost when pod restarts.
**Instead:** Use PVC with persistent storage (local-path or NFS).

### ❌ Anti-Pattern 3: Multiple Replicas with local-path Storage
**What goes wrong:** Local-path binds to a single node; multiple replicas can't share the same PVC, leading to data inconsistency or pod scheduling failures.
**Instead:** Keep replicas=1 for this deployment. If HA is needed in the future, migrate to a shared storage solution (NFS, block storage).

### ❌ Anti-Pattern 4: Exposing AIOStreams Externally
**What goes wrong:** Security risk; Real-Debrid credentials exposed to internet.
**Instead:** Intranet-only via MetalLB LoadBalancer with no external routing (current design).

### ❌ Anti-Pattern 5: Using dataFrom for Sensitive Secrets
**What goes wrong:** All keys from a secret are synced; harder to audit which secrets are in use.
**Instead:** Explicit `data` entries for each required secret key (current design).

---

## Scalability Considerations

| Concern | Current (1 user) | 10 users | 100 users |
|---------|------------------|----------|-----------|
| **Pod replicas** | 1 | 1 | 3-5 (with shared NFS) |
| **Database** | SQLite, local-path PVC | SQLite + local-path OK | PostgreSQL + external DB |
| **Storage** | 10Gi local-path | 50Gi local-path | 500Gi+ NFS or cloud storage |
| **Secrets sync** | ExternalSecret via OpenBao | Same | Same |
| **Service exposure** | MetalLB LoadBalancer | LoadBalancer + caching proxy | Ingress + CDN |

**For this homelab instance:** 1 user, 1 pod, SQLite + local-path is optimal.

---

## Key Decisions Documented

| Decision | Rationale | Status |
|----------|-----------|--------|
| **local-path PVC** | k3s built-in, sufficient for single-user SQLite | ✓ Adopted |
| **ExternalSecret with `data`** | Explicit, auditable secret sync | ✓ Adopted |
| **Port 3000** | AIOStreams default | ✓ Adopted |
| **LoadBalancer service** | Consistent with mcp-servers pattern | ✓ Adopted |
| **Single replica** | Single-user homelab; HA deferred | ✓ Adopted |
| **Namespace isolation** | Workload isolation best practice | ✓ Adopted |

---

## Sources

- [K3s Volumes and Storage](https://docs.k3s.io/add-ons/storage)
- [Rancher Local Path Provisioner](https://github.com/rancher/local-path-provisioner)
- [External Secrets Operator - HashiCorp Vault](https://external-secrets.io/latest/provider/hashicorp-vault/)
- [AIOStreams Configuration - Environment Variables](https://docs.aiostreams.viren070.me/configuration/environment-variables/)
- [AIOStreams GitHub - Deployment](https://github.com/Viren070/AIOStreams/wiki/Deployment)
- [External Secrets Operator - All Keys One Secret](https://external-secrets.io/latest/guides/all-keys-one-secret/)
