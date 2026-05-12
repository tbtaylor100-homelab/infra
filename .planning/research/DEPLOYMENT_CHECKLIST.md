# AIOStreams Deployment Checklist

**Project:** AIOStreams on k3s (ArgoCD-managed)
**Based on:** Architecture research (ARCHITECTURE.md)
**Last Updated:** 2026-05-11

---

## Pre-Deployment Prerequisites

### 1. OpenBao Secret Store
- [ ] Verify OpenBao is accessible at `http://192.168.1.210:8200`
- [ ] Kubernetes auth backend is configured (role: `eso-reader`)
- [ ] Current policy for `eso-reader` includes `secret/data/homelab/ci` read access
- [ ] **Extended policy:** Add `secret/data/aiostreams/*` read access

**How to extend ESO policy:**
```bash
# SSH to OpenBao host or use Vault CLI
vault write auth/kubernetes/role/eso-reader \
  bound_service_account_names=external-secrets \
  bound_service_account_namespaces=external-secrets \
  policies="eso-policy" \
  ttl=1h

# Update eso-policy to include aiostreams path
vault policy write eso-policy - <<EOF
path "secret/data/homelab/ci/*" {
  capabilities = ["read", "list"]
}
path "secret/data/aiostreams/*" {
  capabilities = ["read", "list"]
}
EOF
```

### 2. Prepare Secrets in OpenBao
- [ ] Generate 64-character hex `secret_key` for AIOStreams
- [ ] Obtain Real-Debrid API key from your RD account
- [ ] Write secret to OpenBao:

```bash
SECRET_KEY=$(openssl rand -hex 32)
RD_API_KEY="YOUR_REAL_DEBRID_API_KEY"

vault write secret/aiostreams/production \
  secret_key="$SECRET_KEY" \
  real_debrid_api_key="$RD_API_KEY"

# Verify
vault read secret/aiostreams/production
```

### 3. Git Repository Access
- [ ] Confirm git remote: `http://forgejo.local:3000/root/infra.git`
- [ ] Clone or update local copy
- [ ] Create working branch (recommended: `feature/aiostreams-deployment`)

### 4. k3s Cluster Access
- [ ] kubectl configured to access k3s cluster
- [ ] ArgoCD installed and configured
- [ ] MetalLB installed (for LoadBalancer service)
- [ ] External Secrets Operator installed with `openbao` ClusterSecretStore
- [ ] k3s default storage class is `local-path` (verify: `kubectl get storageclass`)

---

## Step 1: Create Manifest Files

### 1.1 Namespace
**File:** `kubernetes/aiostreams/namespace.yaml`

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: aiostreams
```

### 1.2 Deployment + PVC + Service
**File:** `kubernetes/aiostreams/deployment.yaml`

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
          image: ghcr.io/viren070/aiostreams:latest
          ports:
            - containerPort: 3000
          env:
            - name: PORT
              value: "3000"
            - name: BASE_URL
              valueFrom:
                configMapKeyRef:
                  name: aiostreams-config
                  key: BASE_URL
            - name: DATABASE_URI
              value: "sqlite:///app/data/db.sqlite"
            - name: SECRET_KEY
              valueFrom:
                secretKeyRef:
                  name: aiostreams-secret
                  key: secret_key
            - name: FORCED_SERVICE_CREDENTIALS
              valueFrom:
                secretKeyRef:
                  name: aiostreams-secret
                  key: real_debrid_api_key
            - name: WHITELISTED_REGEX_PATTERNS
              valueFrom:
                configMapKeyRef:
                  name: aiostreams-config
                  key: WHITELISTED_REGEX_PATTERNS
            - name: REGEX_FILTER_ACCESS
              valueFrom:
                configMapKeyRef:
                  name: aiostreams-config
                  key: REGEX_FILTER_ACCESS
          volumeMounts:
            - name: data
              mountPath: /app/data
      volumes:
        - name: data
          persistentVolumeClaim:
            claimName: aiostreams-data
---
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
```

### 1.3 ExternalSecret
**File:** `kubernetes/aiostreams/externalsecret.yaml`

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
    - secretKey: secret_key
      remoteRef:
        key: aiostreams/production
        property: secret_key
    - secretKey: real_debrid_api_key
      remoteRef:
        key: aiostreams/production
        property: real_debrid_api_key
```

### 1.4 ConfigMap
**File:** `kubernetes/aiostreams/configmap.yaml`

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: aiostreams-config
  namespace: aiostreams
data:
  BASE_URL: "http://192.168.1.100:3000"  # Update to your MetalLB IP or hostname
  WHITELISTED_REGEX_PATTERNS: |
    WEB-DL
    AMZN
    DSNP
    YTS
    RARBG
    EZTV
  REGEX_FILTER_ACCESS: "all"
```

**Note:** Update `BASE_URL` after MetalLB assigns an IP to the service, or use a resolvable hostname if you set up local DNS.

---

## Step 2: Create ArgoCD Application

**File:** `argocd/apps/aiostreams.yaml`

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

## Step 3: Commit and Push

```bash
cd /path/to/infra/repo

# Add manifest files
git add kubernetes/aiostreams/
git add argocd/apps/aiostreams.yaml

# Commit
git commit -m "Feat: Deploy AIOStreams on k3s with ArgoCD, ESO, and MetalLB

- Add Kubernetes manifests for AIOStreams Deployment, PVC, Service, ExternalSecret, ConfigMap
- Create ArgoCD Application CR to manage deployment from git
- Configure ExternalSecret to sync Real-Debrid credentials from OpenBao
- Use local-path PVC for SQLite database storage
- Expose via MetalLB LoadBalancer on intranet (port 3000)
"

# Push to Forgejo
git push origin main  # Or your working branch
```

---

## Step 4: Verify Kubernetes Resources

### Check Namespace
```bash
kubectl get ns | grep aiostreams
kubectl describe ns aiostreams
```

### Check PVC Status
```bash
kubectl get pvc -n aiostreams
kubectl describe pvc aiostreams-data -n aiostreams
```

**Expected:** PVC should be `Bound` to a PersistentVolume.

### Check ExternalSecret Sync
```bash
kubectl get externalsecret -n aiostreams
kubectl describe externalsecret aiostreams-secret -n aiostreams
```

**Expected:** Status should show `SecretSynced: true`, and the Secret `aiostreams-secret` should exist.

### Verify Kubernetes Secret
```bash
kubectl get secret -n aiostreams
kubectl get secret aiostreams-secret -n aiostreams -o yaml
```

**Expected:** Secret should contain `secret_key` and `real_debrid_api_key` keys (base64-encoded in YAML).

### Check Deployment Status
```bash
kubectl get deployment -n aiostreams
kubectl describe deployment aiostreams -n aiostreams
kubectl get pods -n aiostreams -o wide
```

**Expected:** Pod should be `Running`.

### Check Pod Logs
```bash
kubectl logs -n aiostreams -l app=aiostreams
# Or follow logs in real-time
kubectl logs -f -n aiostreams -l app=aiostreams
```

**Expected:** Logs should show successful startup without errors like "PermissionError" or "ConnectionError".

### Check Service & LoadBalancer IP
```bash
kubectl get svc -n aiostreams
kubectl describe svc aiostreams -n aiostreams
```

**Expected:** Service type should be `LoadBalancer`, and `EXTERNAL-IP` should show the IP assigned by MetalLB (e.g., `192.168.1.100`).

### Check ArgoCD Application
```bash
# Via CLI
argocd app get aiostreams

# Or view in ArgoCD Web UI (http://argocd-url/applications/aiostreams)
```

**Expected:** Application should show `Synced` status and all resources as `Healthy`.

---

## Step 5: Post-Deployment Validation

### 5.1 Web UI Access
1. Get LoadBalancer IP:
   ```bash
   kubectl get svc aiostreams -n aiostreams -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
   ```
2. Open browser: `http://<lb-ip>:3000`
3. Verify AIOStreams UI loads

### 5.2 Configure Real-Debrid Filter
1. Log in to AIOStreams UI
2. Navigate to Filters / Settings
3. Verify `WHITELISTED_REGEX_PATTERNS` are pre-populated (from ConfigMap)
4. Verify `REGEX_FILTER_ACCESS` is set to "all"

### 5.3 Test with Stremio
1. In Stremio, add the AIOStreams addon:
   - URL: `http://<lb-ip>:3000`
2. Activate the Real-Debrid filter
3. Configure Real-Debrid credentials in Stremio
4. Test a stream search: results should exclude known RD-blocked tags

### 5.4 Database Verification
1. Check database was created:
   ```bash
   kubectl exec -it -n aiostreams $(kubectl get pod -n aiostreams -o name) -- ls -la /app/data/
   ```
   **Expected:** Should show `db.sqlite` file

2. Verify PVC is mounted:
   ```bash
   kubectl exec -it -n aiostreams $(kubectl get pod -n aiostreams -o name) -- df /app/data
   ```
   **Expected:** Should show mounted PVC with 10Gi capacity

---

## Step 6: Monitor & Troubleshoot

### Monitor PVC Usage
```bash
kubectl exec -it -n aiostreams $(kubectl get pod -n aiostreams -o name) -- du -sh /app/data/
```

### Watch Real-Time Logs
```bash
kubectl logs -f -n aiostreams -l app=aiostreams
```

### Restart Pod (if needed)
```bash
kubectl rollout restart deployment/aiostreams -n aiostreams
```

### Common Issues

| Issue | Diagnosis | Resolution |
|-------|-----------|------------|
| **Pod not starting** | `kubectl describe pod -n aiostreams` | Check secret sync, PVC binding, image pull |
| **Secret not syncing** | `kubectl describe externalsecret -n aiostreams` | Verify OpenBao policy allows ESO access |
| **LoadBalancer IP not assigned** | `kubectl describe svc aiostreams -n aiostreams` | Verify MetalLB is running and has available IPs |
| **Database locked errors** | Container logs | Ensure only 1 replica; local-path doesn't support multi-writer |

---

## Post-Deployment Documentation

After deployment is successful:

1. **Update PROJECT.md:**
   - Move `AIOStreams deployed as a k8s workload...` from `Active` to `Validated (Phase: Deployment)`
   - Add LoadBalancer IP to deployment notes

2. **Add to homelab runbook:**
   - How to restart AIOStreams pod
   - How to update regex patterns (edit ConfigMap, restart pod)
   - How to rotate Real-Debrid credentials (update OpenBao secret, ESO syncs automatically)

3. **Create ADR (Architectural Decision Record):**
   - Why local-path PVC over PostgreSQL
   - Why MetalLB LoadBalancer over Traefik IngressRoute
   - Why separate namespace from mcp-servers

---

## Next Phase: Configuration & Tuning

After validation, consider:

- [ ] Fine-tune regex patterns based on Stremio usage
- [ ] Monitor PVC growth and adjust size if needed
- [ ] Add resource requests/limits to Deployment
- [ ] Implement automated backups of `/app/data/db.sqlite`
- [ ] Set up alerting for pod restarts, PVC usage

---

**Checkpoint:** All steps completed? AIOStreams should now be accessible at `http://<lb-ip>:3000` and filtering Real-Debrid streams in Stremio.
