# Technology Stack: AIOStreams k3s Deployment

**Project:** AIOStreams self-hosted filtering proxy on k3s  
**Researched:** 2026-05-11  
**Overall confidence:** HIGH

## Recommended Stack

### Core Application

| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| AIOStreams | v2.29.5 (pinned) | Stremio addon aggregator + regex filter | Active maintenance, stable releases, v2 architecture improved over v1 |
| Container Runtime | k3s builtin (containerd) | Kubernetes container environment | Already deployed in homelab |
| Image Registry | ghcr.io | Official AIOStreams images | Maintained by author, semantic versioning |

### Persistent Storage

| Technology | Configuration | Purpose | Why |
|------------|---------------|---------|-----|
| SQLite 3 | `/app/data/db.sqlite` | User config, addon cache, regex patterns | Simplest for single-user instance; no external DB dependency |
| Kubernetes PVC | 1Gi minimum | Mount point for `/app/data` | Survives pod restarts; supports k3s local storage |

### Networking & Secrets

| Technology | Configuration | Purpose | Why |
|------------|---------------|---------|-----|
| MetalLB LoadBalancer | Intranet IP | Service exposure | Consistent with existing mcp-servers pattern; LAN-only access |
| ExternalSecret (ESO) | OpenBao `secret/data/aiostreams/production` | Credential sync | Existing homelab secret management; no plaintext in git |
| OpenBao | Vault-compatible KV v2 | Secret storage backend | Already deployed; supports eso-policy auth scoping |

## Required Environment Variables (Exact Names Verified)

### Critical (Application Won't Start Without These)

```bash
# 64-character hex string (generate with: openssl rand -hex 32)
SECRET_KEY=<64_char_hex_string>

# Base URL accessible to Stremio clients (http://internal-ip:3000 for LAN)
BASE_URL=http://<aiostreams-internal-ip>:3000

# Port AIOStreams listens on (default 3000)
PORT=3000
```

### Real-Debrid Service Credentials (Verified Format)

```bash
# Format: serviceId.credentialId=value
# Real-Debrid serviceId: "realdebrid"
# Real-Debrid credentialId: "apiKey"
# Multi-line example:
FORCED_SERVICE_CREDENTIALS="realdebrid.apiKey=<your_real_debrid_api_key>"

# Alternative if multi-line not supported:
FORCED_SERVICE_CREDENTIALS=realdebrid.apiKey=<your_real_debrid_api_key>
```

**Source:** Verified against AIOStreams WebSearch results and official environment variable docs. Format "serviceId.credentialId=value" confirmed; Real-Debrid uses service ID "realdebrid" and credential ID "apiKey".

### Filtering Configuration

```bash
# Enable regex filter without per-user trust requirement
REGEX_FILTER_ACCESS=all

# Pre-populate regex patterns (JSON array of pattern strings)
# Example: patterns to exclude common RD-blocked release tags
WHITELISTED_REGEX_PATTERNS='[
  "/(\\[(Aergia|smol)\\]|-(Aergia(?!-raws)|smol)\\b)/i",
  "/(WEB-DL|AMZN|DSNP|YTS|RARBG|EZTV)/i"
]'
```

**Note:** JSON array format verified in official docs. Patterns use JavaScript regex syntax with flags.

### Database Configuration

```bash
# SQLite path (default; can override if needed)
DATABASE_URI=sqlite://./data/db.sqlite

# For PostgreSQL (not recommended for this use case):
# DATABASE_URI=postgresql://user:pass@postgres-host:5432/aiostreams
```

**Note:** Default SQLite configuration works; overriding DATABASE_URI is only necessary if using external PostgreSQL (out of scope per PROJECT.md).

### Optional Configuration

```bash
# Application display name in Stremio UI (default: "AIOStreams")
ADDON_NAME=AIOStreams

# Unique addon ID (default: "aiostreams"; must be unique if multiple instances)
ADDON_ID=aiostreams

# Proxy configuration for regional/IP block bypass (optional)
# ADDON_PROXY=<proxy_url>
# ADDON_PROXY_CONFIG=addon1,addon2  # which addons route through proxy
```

## Database Strategy

### SQLite on Kubernetes PVC

**Path inside container:** `/app/data/db.sqlite`  
**PVC mount:** `/app/data` → Kubernetes PVC

**Rationale:**
- Single-user instance with predictable load (one homelab user)
- No external PostgreSQL dependency to manage
- PVC ensures persistence across pod restarts and node rescheduling
- SQLite v3 is efficient for <1000 concurrent connections (homelab use case)

**Implementation:**
```yaml
# Kubernetes PVC (1Gi minimum; adjust based on regex pattern/cache growth)
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: aiostreams-data
  namespace: default
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: local-path  # k3s default
  resources:
    requests:
      storage: 2Gi  # Allow room for regex pattern cache

# Pod volume mount
volumeMounts:
  - name: data
    mountPath: /app/data

volumes:
  - name: data
    persistentVolumeClaim:
      claimName: aiostreams-data
```

**Capacity notes:**
- db.sqlite file: typically <50MB for single user
- Recommended PVC size: 2Gi (leaves headroom for pattern cache, logs)
- Monitor in early phases; adjust if needed

## Resource Profile (Single-User Homelab Instance)

### CPU & Memory Requests/Limits

| Resource | Request | Limit | Rationale |
|----------|---------|-------|-----------|
| CPU | 100m | 500m | Lightweight aggregator; no heavy computation; 500m prevents runaway during regex evaluation |
| Memory | 128Mi | 256Mi | Minimal state; pattern cache + SQLite buffer fit easily |

**Reasoning:**
- AIOStreams aggregates addon results but does not transcode or compute streams
- Regex filtering is fast for single-user filtering volumes
- Single-node k3s cluster with plenty of headroom
- Avoid overprovisioning to leave resources for other homelab services

### Startup Configuration

```yaml
# Pod spec
resources:
  requests:
    cpu: 100m
    memory: 128Mi
  limits:
    cpu: 500m
    memory: 256Mi

# Startup grace period (allow DB initialization)
terminationGracePeriodSeconds: 30
```

## Health Check Endpoints

### Liveness Probe (Pod Restart Detection)

**Endpoint:** `GET /api/v1/status`  
**Port:** 3000 (default)  
**Expected response:** HTTP 200 (application responding)

```yaml
livenessProbe:
  httpGet:
    path: /api/v1/status
    port: 3000
  initialDelaySeconds: 10    # Allow startup time
  periodSeconds: 10
  timeoutSeconds: 5
  failureThreshold: 3
```

### Readiness Probe (Traffic Acceptance)

**Endpoint:** `GET /api/v1/status`  
**Port:** 3000  
**Expected response:** HTTP 200 (database connected, ready to serve)

```yaml
readinessProbe:
  httpGet:
    path: /api/v1/status
    port: 3000
  initialDelaySeconds: 5     # Quick readiness
  periodSeconds: 5
  timeoutSeconds: 3
  failureThreshold: 2
```

**Source:** Health check endpoint `/api/v1/status` verified in official AIOStreams Docker Compose health check configuration. V2 moved from `/health` (v1) to `/api/v1/status`.

## Image Tag Strategy

### Recommended: Pinned Stable Release

**Tag:** `ghcr.io/viren070/aiostreams:v2.29.5`

**Rationale:**
- Explicit version pinning prevents silent breaking changes
- Stable releases follow semantic versioning (v2.x.x)
- Current stable version (May 2026): v2.29.5
- Docker `latest` tag points to stable release (safe to use if explicit version not needed)

**Why NOT `nightly`:**
- Nightly builds (e.g., `2026.05.09.1827-nightly`) break frequently
- Homelab production should prioritize stability over cutting-edge features
- Regex filter itself is stable; no need to track development builds

### Version Update Strategy

1. **Check releases** at https://github.com/Viren070/AIOStreams/releases monthly
2. **Update in ArgoCD** by bumping image tag in Kubernetes manifests
3. **ArgoCD syncs** change automatically (GitOps)
4. **Monitor** `/api/v1/status` readiness probe during rollout

**Source:** AIOStreams maintains two tag strategies: semantic versions (v2.x.x) and nightly timestamped builds. Current stable is v2.29.5 (May 9, 2026).

## Installation & Deployment Commands

### Secret Setup (First-Time Only)

```bash
# Generate SECRET_KEY locally
SECRET_KEY=$(openssl rand -hex 32)
echo $SECRET_KEY

# Store in OpenBao (via runbook/manual process)
# Path: secret/data/aiostreams/production
# Key: SECRET_KEY
# Value: <64_char_hex_string>

# Also store Real-Debrid API key at same path
# Key: FORCED_SERVICE_CREDENTIALS_RD_APIKEY
# Value: <your_real_debrid_api_key>
```

### Kubernetes Manifest Structure

```bash
# In infra/kubernetes/aiostreams/ create:
# - deployment.yaml (Pod, containers, probes, resources)
# - service.yaml (ClusterIP or LoadBalancer)
# - pvc.yaml (Persistent volume claim)
# - externalsecret.yaml (ESO sync from OpenBao)

# In infra/argocd/apps/ create:
# - aiostreams.yaml (ArgoCD Application CR)
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
    path: kubernetes/aiostreams
    targetRevision: main
  destination:
    server: https://kubernetes.default.svc
    namespace: default
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

## Alternatives Considered

| Component | Recommended | Alternative | Why Not |
|-----------|-------------|-------------|---------|
| Image source | ghcr.io/viren070/aiostreams | Docker Hub (viren070/aiostreams) | ghcr.io is official and preferred by author |
| Storage | SQLite on PVC | PostgreSQL external | No existing Postgres; adds operational complexity |
| Storage | SQLite on PVC | Ephemeral (no persistence) | User config and regex patterns would be lost on restart |
| Service exposure | MetalLB LoadBalancer | Traefik IngressRoute | Consistent with homelab pattern; hostname migration deferred |
| Image tag | v2.29.5 pinned | latest tag | Pinning prevents silent upgrades; "latest" is acceptable if auto-upgrade desired |
| Health check | /api/v1/status | None/TCP probe | HTTP endpoint is more reliable; TCP would miss application hangs |

## Sources

- [AIOStreams GitHub Repository](https://github.com/Viren070/AIOStreams)
- [AIOStreams Releases](https://github.com/Viren070/AIOStreams/releases) - v2.29.5 is current stable (May 2026)
- [AIOStreams Environment Variables Documentation](https://docs.aiostreams.viren070.me/configuration/environment-variables/)
- [AIOStreams Deployment Wiki](https://github.com/Viren070/AIOStreams/wiki/Deployment)
- [AIOStreams GitHub Container Registry](https://github.com/Viren070/AIOStreams/pkgs/container/aiostreams)
- [AIOStreams Setup Guide](https://guides.viren070.me/stremio/addons/aiostreams/setup)
- [FORCED_SERVICE_CREDENTIALS Real-Debrid Format (Issue #266)](https://github.com/Viren070/AIOStreams/issues/266)

## Confidence Levels

| Area | Level | Notes |
|------|-------|-------|
| Image tag strategy | HIGH | Current stable v2.29.5 confirmed via releases page; semantic versioning established |
| FORCED_SERVICE_CREDENTIALS format | HIGH | Format "serviceId.credentialId=value" verified; Real-Debrid uses "realdebrid.apiKey" from official docs |
| Database path | HIGH | `/app/data/db.sqlite` confirmed in official deployment docs; DATABASE_URI default verified |
| Health check endpoint | HIGH | `/api/v1/status` confirmed in Docker Compose health check configuration; v1 /health endpoint deprecated |
| Resource profile | MEDIUM | Estimates based on single-user homelab use case; should be validated post-deploy with actual metrics |
| PVC sizing (2Gi) | MEDIUM | Conservative estimate; should monitor growth and adjust in Phase 2 |
| Secret name format | MEDIUM | OpenBao path `secret/data/aiostreams/production` follows convention; actual ESO binding needs validation in Phase 1 |
