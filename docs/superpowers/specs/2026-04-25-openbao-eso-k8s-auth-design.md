# MAH-70: OpenBao + ESO + Forgejo OIDC Auth Design

**Date:** 2026-04-25
**Jira:** MAH-70
**Status:** Approved

## Problem

The Forgejo Actions CI runner authenticates to OpenBao using AppRole — two static credentials (`OPENBAO_ROLE_ID`, `OPENBAO_SECRET_ID`) stored as Forgejo repo secrets. Static credentials never expire, must be rotated manually, and represent a stored-credential risk.

Additionally, CI workflows manually fetch secrets from OpenBao and inject them as env vars in every workflow file — duplicating that logic across `tofu-plan.yml` and `tofu-apply.yml`.

## Goal

Eliminate all stored credentials from Forgejo. CI jobs authenticate to OpenBao using short-lived, per-job Forgejo OIDC tokens. External Secrets Operator is deployed as foundational infrastructure for future K8s application pods to pull secrets from OpenBao.

## Architecture

### CI workflows (Forgejo OIDC → OpenBao JWT auth)

```
Forgejo v15 issues per-job OIDC JWT (ACTIONS_ID_TOKEN_REQUEST_URL)
    ↓
CI step requests token → presents JWT to OpenBao JWT auth backend
    ↓
OpenBao validates JWT against Forgejo JWKS (http://192.168.1.50:3000/login/oauth/keys)
    ↓
Returns BAO_TOKEN → read secret/homelab/ci → inject as env vars
    ↓
Subsequent steps read $PROXMOX_API_TOKEN, $AWS_ACCESS_KEY_ID, etc.
```

### K8s application pods (ESO — future use)

```
OpenBao (openbao namespace)
    ↑  Kubernetes auth — ESO's ServiceAccount
External Secrets Operator (external-secrets namespace)
    ↓  ExternalSecret → K8s Secret in app namespace
App pod envFrom: secretRef
```

ESO is deployed now as the standard pattern for K8s applications. The forgejo-runner itself does not use ESO — CI jobs use per-job OIDC tokens.

## Why this approach

- **No stored credentials anywhere** — Forgejo OIDC tokens are issued per-job by the platform, never stored
- **Per-job token scoping** — tokens expire when the job ends; cannot be reused
- **Claim-based access control** — OpenBao role can restrict `tofu-apply` to `refs/heads/main` only
- **ESO as foundational infrastructure** — deployed now, ready for future K8s apps without rework
- **GitOps-consistent** — all resources declared in git, managed by ArgoCD

## Why not K8s ServiceAccount tokens for CI

K8s SA tokens are pod-scoped, not job-scoped. Any job running on the runner pod could read the same token. Forgejo OIDC tokens carry workflow-level claims (`repository`, `ref`, `workflow`) enabling finer-grained access control.

## Why not AppRole

Static credentials stored in Forgejo. Never expire. Someone had to put them there manually.

## Prerequisites

1. **SSH access to `ubuntu@192.168.1.50`** — add `id_ed25519.pub` to `~/.ssh/authorized_keys` via Proxmox console. Required for Ansible to manage the Forgejo VM.
2. **OpenBao root token** — created during `bao operator init`. Required for the Ansible playbook to configure auth backends.

## Components

### New: Forgejo upgrade to v15

**Confirmed:** Forgejo is a binary install running as the `git` system user on VM `.50`, managed by systemd.

New Ansible role `ansible/roles/forgejo/` and playbook `ansible/playbooks/forgejo-upgrade.yml`:
1. Download Forgejo v15 binary from releases
2. Stop `forgejo` systemd service
3. Replace binary
4. Start service
5. Verify version via API (`/api/v1/version`)

The Forgejo runner (`gitea/act_runner`) in the K3s Deployment must be pinned to `v12.5.0` or later — required for `ACTIONS_ID_TOKEN_REQUEST_URL` support.

### New: `argocd/apps/external-secrets.yaml`

ArgoCD Application CRD pointing at the ESO Helm chart (`oci://ghcr.io/external-secrets/charts/external-secrets`, pinned version). ArgoCD self-heals if ESO drifts or is deleted.

### New: `kubernetes/external-secrets/`

ESO Helm chart values and `ClusterSecretStore`:

- **`values.yaml`** — minimal overrides (serviceAccount name, metrics)
- **`cluster-secret-store.yaml`** — cluster-scoped connection config for OpenBao:
  - Address: `http://192.168.1.210:8200`
  - Auth: Kubernetes (ESO's ServiceAccount `external-secrets` in `external-secrets` namespace)
  - Cluster-scoped so any future namespace can reference it without duplicating connection config

### New: `ansible/playbooks/openbao-auth-config.yml`

Idempotent playbook run once against the live cluster. Safe to re-run on cluster rebuild.

**Prerequisite:** Uses OpenBao root token via `kubectl exec -n openbao openbao-0` from `192.168.1.60`.

Steps:
1. Enable Kubernetes auth backend (for ESO)
2. Configure Kubernetes backend: API server `https://192.168.1.60:6443`, CA cert from cluster
3. Create role `eso-reader` — binds ServiceAccount `external-secrets` / namespace `external-secrets` to a read policy
4. Enable JWT auth backend (for Forgejo OIDC CI tokens)
5. Configure JWT backend: JWKS URL `http://192.168.1.50:3000/login/oauth/keys`, issuer `http://192.168.1.50:3000`
6. Create policy `ci-reader` — read on `secret/data/homelab/ci`
7. Create JWT role `ci-plan` — bound to `ci-reader`, accepts any `ref`, bound to `repository: root/infra`
8. Create JWT role `ci-apply` — bound to `ci-reader`, restricted to `ref: refs/heads/main` only

### Updated: `kubernetes/forgejo-runner/deployment.yaml`

Pin runner image from `gitea/act_runner:latest` to `gitea/act_runner:0.2.11` (v12.5.0+). No other changes — runner does not use `envFrom` for secrets.

### Updated: `.forgejo/workflows/tofu-plan.yml` and `tofu-apply.yml`

Replace the AppRole "Fetch secrets from OpenBao" block with Forgejo OIDC auth:

```bash
# Request per-job OIDC token from Forgejo
OIDC_TOKEN=$(curl -sf \
  -H "Authorization: bearer $ACTIONS_ID_TOKEN_REQUEST_TOKEN" \
  "${ACTIONS_ID_TOKEN_REQUEST_URL}&audience=openbao" | jq -r '.value')

# Exchange OIDC token for OpenBao token
BAO_TOKEN=$(curl -sf --request POST \
  --data "{\"jwt\":\"$OIDC_TOKEN\",\"role\":\"ci-plan\"}" \
  http://192.168.1.210:8200/v1/auth/jwt/login | jq -r '.auth.client_token')

# Read secrets and inject as env vars (unchanged from today)
SECRETS=$(curl -sf \
  --header "X-Vault-Token: $BAO_TOKEN" \
  http://192.168.1.210:8200/v1/secret/data/homelab/ci | jq -r '.data.data')
# ... echo into $GITHUB_ENV
```

`tofu-apply.yml` uses role `ci-apply` (main-branch-only restriction).

## Testing

Following TDD — verification at each layer before proceeding to the next.

### 1. Forgejo upgrade
```bash
curl -s http://192.168.1.50:3000/api/v1/version
# Expected: {"version":"15.x.x+..."}
```

### 2. ESO healthy
```bash
kubectl get pods -n external-secrets
kubectl get crds | grep external-secrets.io
```
All pods Running, CRDs installed.

### 3. ClusterSecretStore can authenticate to OpenBao
```bash
kubectl get clustersecretstore openbao -o jsonpath='{.status.conditions}'
# Expected: Ready: True
```
If auth fails here, the Ansible Kubernetes auth configuration is wrong.

### 4. Forgejo OIDC endpoint is live
```bash
curl -s http://192.168.1.50:3000/login/oauth/keys | jq '.keys | length'
# Expected: > 0 (JWKS keys present)
```

### 5. OpenBao JWT auth backend accepts Forgejo tokens
Create a scratch workflow (`.forgejo/workflows/test-oidc.yml`, `branches: [test/oidc-*]`) that:
1. Requests an OIDC token
2. Logs the decoded JWT claims (not the token itself) to confirm `repository` and `ref` claims are correct
3. Exchanges it for a BAO_TOKEN and confirms a non-empty response
4. Reads one non-sensitive key from `secret/homelab/ci` (e.g., `proxmox_endpoint`) and prints it

Delete the test workflow before merging to main.

### 6. Real CI run
Open a PR with a trivial OpenTofu whitespace change:
- `tofu-plan.yml` completes without error using `ci-plan` role
- Plan output reflects actual Proxmox state (confirms token was valid)
- No "AppRole" anywhere in workflow logs

Merge to main:
- `tofu-apply.yml` completes using `ci-apply` role (main-branch restriction exercised)

### 7. Branch restriction enforcement
Open a second PR and manually trigger `tofu-apply.yml` from the PR branch. OpenBao must reject the JWT (wrong `ref` claim). Confirm CI step fails with an auth error, not a Proxmox error.

## Cleanup (after step 6 confirmed)

1. Delete `OPENBAO_ROLE_ID` and `OPENBAO_SECRET_ID` from Forgejo repo secrets
2. Disable AppRole auth in OpenBao: `bao auth disable approle`
3. Delete the test workflow file if not already removed

## Ordering

1. Provision SSH access to `ubuntu@192.168.1.50` (Proxmox console)
2. Run `ansible/playbooks/forgejo-upgrade.yml` — upgrade to v15
3. Verify Forgejo v15 via API (test step 1)
4. Deploy ESO via ArgoCD (verify test steps 2–3)
5. Run `ansible/playbooks/openbao-auth-config.yml` — configure both auth backends
6. Verify JWKS endpoint live (test step 4)
7. Pin runner image, ArgoCD reconciles
8. Run test workflow on `test/oidc-*` branch (test step 5)
9. Update CI workflows to use OIDC, open PR (test step 6)
10. Verify branch restriction (test step 7)
11. Cleanup

## Out of Scope

- Replacing DinD (`docker:27-dind`, `privileged: true`) — known security gap, separate ticket
- OpenTofu credentials for Proxmox API access — separate concern, separate ticket
- ESO usage for CI workflows — ESO is for K8s app pods only; tracked in follow-up ticket
