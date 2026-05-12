# Technical FAQ: AIOStreams on k3s

**Quick reference answers to your research questions**

---

## Q1: What k8s resources are needed?

**A:** Six core resources in the `aiostreams` namespace:

1. **Namespace** — Isolation boundary (`metadata.name: aiostreams`)
2. **Deployment** — Single pod running AIOStreams container
3. **PersistentVolumeClaim (PVC)** — Storage for SQLite database
4. **PersistentVolume (PV)** — Auto-created by k3s local-path provisioner
5. **ExternalSecret** — Syncs secrets from OpenBao to Kubernetes Secret
6. **Service** — LoadBalancer exposing port 3000 to intranet
7. **ConfigMap** (optional) — Non-secret configuration (regex patterns, feature flags)

**Plus (pre-existing):**
- **ClusterSecretStore/openbao** — Already defined, extended with `secret/data/aiostreams/*` policy
- **ArgoCD Application** — Points to `kubernetes/aiostreams/` path in git

---

## Q2: What PVC storage class should be used on k3s?

**A:** **`local-path`** (k3s built-in default)

**Details:**
- **provisioner:** `rancher.io/local-path`
- **persistence:** Stored on node filesystem at `/var/lib/rancher/k3s/storage/`
- **node affinity:** Implicit — pod must run on the node where PV is created
- **perfect for:** Single-user homelab, SQLite databases, non-distributed workloads
- **not suitable for:** Multi-node HA or frequent node migration

**Verification:**
```bash
kubectl get storageclass
# Output: local-path (default)
```

---

## Q3: ExternalSecret: dataFrom vs data (individual keys)?

**A:** Use **`data` (individual keys)** for AIOStreams.

**Comparison:**

| Approach | Use Case | Security | Auditability |
|----------|----------|----------|--------------|
| **data** (individual keys) | Few, known secrets | HIGH (explicit) | HIGH (clear) |
| **dataFrom** (all keys) | Many dynamic secrets | MEDIUM (implicit) | MEDIUM (opaque) |

**Why `data` for AIOStreams:**
- Only 2 secrets needed: `secret_key` and `real_debrid_api_key`
- Explicit specification makes it clear which secrets are in use
- Better for audit/compliance
- If future config adds more secrets, they're listed here

**Pattern:**
```yaml
spec:
  data:
    - secretKey: secret_key
      remoteRef:
        key: aiostreams/production
        property: secret_key
    - secretKey: real_debrid_api_key
      remoteRef:
        key: aiostreams/production
        property: real_debrid_api_key
```

**Alternative (if you prefer dataFrom):**
```yaml
spec:
  dataFrom:
    - extract:
        key: aiostreams/production
```
Less recommended for sensitive credentials.

---

## Q4: ExternalSecret remoteRef format for Vault v2 KV?

**A:** Use **`key` and `property` fields** as follows:

**Format:**
```yaml
remoteRef:
  key: aiostreams/production      # Path in Vault (no /data/ prefix)
  property: secret_key            # Specific property within the secret
```

**How it works:**
- `key` = secret path (ESO automatically prepends `/data/` for KV v2)
- `property` = gjson expression to extract nested value
- **Leave `property` empty** to fetch all key-value pairs as JSON

**Examples:**

| Goal | remoteRef |
|------|-----------|
| Get `secret_key` from `secret/aiostreams/production` | `key: aiostreams/production` + `property: secret_key` |
| Get `credentials.api_key` (nested) | `key: aiostreams/production` + `property: credentials.api_key` |
| Get all keys as JSON object | `key: aiostreams/production` (no property) |

**Vault path structure:**
```
secret/data/aiostreams/production    # Full path in Vault v2 KV
         └─ /data/ added by ESO
```
You specify only: `aiostreams/production`

---

## Q5: SQLite PVC mount path and DATABASE_URI?

**A:** Use these settings:

**mount:**
```yaml
volumeMounts:
  - name: data
    mountPath: /app/data
```

**DATABASE_URI:**
```yaml
env:
  - name: DATABASE_URI
    value: "sqlite:///app/data/db.sqlite"
```

**Why `/app/data`:**
- AIOStreams default convention (from `.env.sample`)
- Container starts at `/app` directory
- SQLite database file: `/app/data/db.sqlite`

**PVC spec:**
```yaml
spec:
  resources:
    requests:
      storage: 10Gi
  storageClassName: local-path
  accessModes:
    - ReadWriteOnce
```

**Result:**
- PVC mounted at `/app/data`
- SQLite database persisted to PVC
- Survives pod restart (stored on k3s node's `/var/lib/rancher/k3s/storage/`)

---

## Q6: Service type and port exposure?

**A:** **LoadBalancer service on port 3000**

**Service spec:**
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

**Port reasoning:**
- **Container port:** 3000 (AIOStreams default, from `PORT` env var)
- **Service port:** 3000 (no translation)
- **LoadBalancer IP:** Assigned by MetalLB from intranet pool (e.g., `192.168.1.100`)

**Access pattern:**
```
Stremio client (192.168.1.x) → LoadBalancer IP:3000 → Service:3000 → Pod:3000
```

**MetalLB integration:**
- MetalLB is already deployed (existing infra)
- Service automatically gets an intranet IP from MetalLB pool
- No manual configuration needed

---

## Q7: Init containers needed?

**A:** **No, not required** for AIOStreams.

**Why:**
- AIOStreams creates the database on first run (SQLite auto-init)
- PVC is ready before container starts
- No pre-flight checks or migrations needed for v1 deployment

**When you'd use init containers:**
- Database schema migrations (future: PostgreSQL upgrade)
- Pre-loading seed data
- Checking external dependencies (e.g., Real-Debrid API connectivity)

**For now:** Start with just the main container. Add init containers if future phases need them.

---

## Q8: Environment variable FORMAT for Real-Debrid credentials?

**A:** Use the standard format from `.env.sample`:

**Key name in OpenBao:**
```
real_debrid_api_key
```

**How to use in AIOStreams:**
```yaml
env:
  - name: FORCED_SERVICE_CREDENTIALS
    valueFrom:
      secretKeyRef:
        name: aiostreams-secret
        key: real_debrid_api_key
```

**Value format in OpenBao:**
```
Just the API key string, e.g.:
"abc123def456ghi789jkl012mno345pqr678stu"
```

**Note:** The `FORCED_SERVICE_CREDENTIALS` environment variable name comes from AIOStreams docs. The actual value is the Real-Debrid API key (no special formatting required — just the key itself).

---

## Q9: What happens when ESO extends the policy?

**A:** Sequence of events:

1. **You update OpenBao policy** to include `secret/data/aiostreams/*`
2. **ExternalSecret controller** sees the new ClusterSecretStore reference
3. **ESO Kubernetes auth** attempts to read `secret/aiostreams/production` from OpenBao
4. **OpenBao policy** checks: does `eso-reader` role allow `secret/data/aiostreams/production`? → YES (from new policy)
5. **Secret syncs:** ExternalSecret creates Kubernetes Secret `aiostreams-secret` with keys from OpenBao
6. **Deployment mounts:** Deployment reads Secret, injects values into container env vars

**If policy is NOT extended:**
- ExternalSecret controller logs: `Permission denied` or `Forbidden`
- Secret is NOT created
- Deployment pod cannot start (missing required secrets)

---

## Q10: Where is the ArgoCD Application?

**A:** File path: `argocd/apps/aiostreams.yaml`

**Reference (following mcp-servers.yaml pattern):**
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

**Flow:**
1. Commit this Application CR to git
2. ArgoCD controller detects new Application
3. ArgoCD reads `kubernetes/aiostreams/` from git
4. ArgoCD applies all manifests to k3s cluster
5. Resources created: Namespace, Deployment, PVC, Service, ExternalSecret, ConfigMap
6. Auto-sync enabled: any git push automatically updates the cluster

---

## Q11: How do I debug if something goes wrong?

**A:** Debugging checklist:

**Pod not starting:**
```bash
kubectl describe pod -n aiostreams -l app=aiostreams
# Look for: ImagePullBackOff, CrashLoopBackOff, Pending
kubectl logs -n aiostreams -l app=aiostreams
# Look for: error messages, stack traces
```

**Secret not syncing:**
```bash
kubectl describe externalsecret -n aiostreams
# Look for: SecretSynced=False, conditions
kubectl describe secret -n aiostreams aiostreams-secret
# Should exist if sync succeeded
```

**PVC not binding:**
```bash
kubectl describe pvc -n aiostreams
# Look for: Pending status, node affinity issues
```

**Service has no LoadBalancer IP:**
```bash
kubectl describe svc -n aiostreams
# Look for: EXTERNAL-IP stuck at <pending>
# Verify MetalLB is running: kubectl get pods -n metallb-system
```

**ArgoCD sync failed:**
```bash
argocd app get aiostreams
# Look for: OutOfSync status, sync errors
argocd app sync aiostreams --prune  # Force sync
```

---

## Summary Table

| Question | Answer | Reference |
|----------|--------|-----------|
| **Resources** | Namespace, Deployment, PVC, Service, ExternalSecret, ConfigMap | ARCHITECTURE.md §Resource Inventory |
| **Storage Class** | `local-path` (k3s default) | Q2 |
| **ExternalSecret Method** | `data` (individual keys) | Q3 |
| **remoteRef Format** | `key: aiostreams/production` + `property: <key>` | Q4 |
| **Mount Path** | `/app/data` | Q5 |
| **DATABASE_URI** | `sqlite:///app/data/db.sqlite` | Q5 |
| **Service Type** | LoadBalancer | Q6 |
| **Port** | 3000 | Q6 |
| **Init Containers** | Not required | Q7 |
| **RD Credentials** | `FORCED_SERVICE_CREDENTIALS` env var | Q8 |
| **ArgoCD App Path** | `argocd/apps/aiostreams.yaml` | Q10 |

---

**All answers verified against:**
- AIOStreams official docs (Environment Variables, Deployment)
- External Secrets Operator Vault provider docs
- k3s storage documentation
- Existing infra patterns (mcp-servers.yaml, cluster-secret-store.yaml)
