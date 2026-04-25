# MAH-70: OpenBao + ESO Kubernetes Auth Design

**Date:** 2026-04-25
**Jira:** MAH-70
**Status:** Approved

## Problem

The Forgejo Actions CI runner authenticates to OpenBao using AppRole — two static credentials (`OPENBAO_ROLE_ID`, `OPENBAO_SECRET_ID`) stored as Forgejo repo secrets. Static credentials never expire, must be rotated manually, and represent a stored-credential risk.

Additionally, CI workflows manually fetch secrets from OpenBao and inject them as env vars in every workflow file — duplicating that logic across `tofu-plan.yml` and `tofu-apply.yml`.

## Goal

Eliminate all stored credentials from Forgejo. K3s pulls secrets from OpenBao via External Secrets Operator and injects them into pods as env vars. CI workflow steps read from env directly — no OpenBao calls in any workflow file.

## Architecture

```
OpenBao (openbao namespace)
    ↑  Kubernetes auth — ESO's ServiceAccount
External Secrets Operator (external-secrets namespace)
    ↓  syncs secret/homelab/ci → K8s Secret (forgejo-runner namespace)
forgejo-runner pod
    ↓  envFrom: secretRef: ci-secrets
CI workflow steps read $PROXMOX_API_TOKEN, $AWS_ACCESS_KEY_ID, etc. from env
```

### Why this approach

- **No stored credentials anywhere** — ESO authenticates to OpenBao using its K8s ServiceAccount identity, which is issued by the platform and never stored in git or Forgejo
- **Single auth point** — ESO is the only workload that authenticates to OpenBao; all other pods receive secrets via K8s Secrets
- **CI workflows simplified** — the "Fetch secrets from OpenBao" step is removed entirely from both workflow files
- **GitOps-consistent** — all new resources are declared in git and managed by ArgoCD

### Why not AppRole

AppRole requires storing `role_id` + `secret_id` somewhere (Forgejo secrets). Someone created those manually and they never expire. K8s ServiceAccount tokens are platform-issued, scoped to the pod's identity, and rotate automatically.

### Why not Forgejo OIDC workflow tokens

Forgejo 14.0.3 does not expose the Actions-specific OIDC token endpoint (`ACTIONS_ID_TOKEN_REQUEST_URL`) required for per-job JWT federation. The OAuth OIDC endpoint is live but serves user login flows, not CI job identity. Revisit when Forgejo adds Actions OIDC support.

### Why keep runner in K3s

Isolation: the runner pod can be killed or restarted independently without affecting the Forgejo VM (.50). If the runner misbehaves, Kubernetes terminates it cleanly.

## Components

### New: `kubernetes/external-secrets/`

ESO Helm chart deployed via ArgoCD. Creates the `external-secrets` namespace, installs the operator and its CRDs, and creates the ESO ServiceAccount that OpenBao's Kubernetes auth backend will grant access to.

### New: `argocd/apps/external-secrets.yaml`

ArgoCD Application CRD pointing at the ESO Helm chart (`external-secrets.io` chart repo, pinned version). ArgoCD self-heals if the deployment is deleted or drifts.

### New: `kubernetes/external-secrets/cluster-secret-store.yaml`

A `ClusterSecretStore` resource — ESO's connection configuration for OpenBao:
- OpenBao address: `http://192.168.1.210:8200`
- Auth method: Kubernetes
- Role: `eso-ci` (created by Ansible)

A `ClusterSecretStore` (cluster-scoped) is used rather than a namespace-scoped `SecretStore` so that other namespaces can sync secrets from OpenBao in the future without duplicating the connection config.

### New: `kubernetes/forgejo-runner/external-secret.yaml`

An `ExternalSecret` resource in the `forgejo-runner` namespace:
- Reads all keys from `secret/homelab/ci` in OpenBao
- Creates and maintains a K8s Secret named `ci-secrets` in the `forgejo-runner` namespace
- Refresh interval: 1h

### Updated: `kubernetes/forgejo-runner/deployment.yaml`

Add `envFrom: - secretRef: name: ci-secrets` to the runner container. All CI secrets become ambient env vars in the pod. No other changes to the Deployment.

### New: `ansible/playbooks/openbao-k8s-auth.yml`

Idempotent playbook that configures OpenBao's Kubernetes auth backend against the live cluster. Runs once; safe to re-run if the cluster is rebuilt.

**Prerequisite:** The playbook authenticates to OpenBao using the root token. It accesses the root token by running `kubectl exec` into the OpenBao pod (`openbao-0` in the `openbao` namespace) from the K3s control plane node (`192.168.1.60`). The root token must exist — it was created during `bao operator init` when OpenBao was first initialized.

Steps:
1. Enable Kubernetes auth backend: `bao auth enable kubernetes`
2. Configure backend: K3s API server at `https://192.168.1.60:6443`, CA cert read from the cluster
3. Create policy `ci-reader` — read access on `secret/data/homelab/ci`
4. Create role `eso-ci` — binds ServiceAccount `external-secrets` in namespace `external-secrets` (ESO Helm chart default) to `ci-reader`

### Updated: `.forgejo/workflows/tofu-plan.yml` and `tofu-apply.yml`

Remove the "Fetch secrets from OpenBao" step entirely (the AppRole login + curl + masking + `$GITHUB_ENV` injection block). Secrets are already in the runner's env via `envFrom`. All subsequent steps that reference `$TF_VAR_proxmox_api_token`, `$AWS_ACCESS_KEY_ID`, etc. continue to work unchanged.

## Cleanup (after CI is confirmed working)

1. Delete `OPENBAO_ROLE_ID` and `OPENBAO_SECRET_ID` from Forgejo repo secrets
2. Disable AppRole auth method in OpenBao: `bao auth disable approle`

## Ordering

The following sequence must be respected to avoid breaking CI mid-deploy:

1. Deploy ESO (ArgoCD syncs `external-secrets` app)
2. Run Ansible playbook to configure OpenBao Kubernetes auth
3. Apply `ClusterSecretStore` and `ExternalSecret` — ESO syncs `ci-secrets` K8s Secret
4. Confirm `ci-secrets` Secret exists in `forgejo-runner` namespace with expected keys
5. Update `deployment.yaml` to add `envFrom` — ArgoCD reconciles runner pod
6. Merge CI workflow changes — confirm a real CI run reads secrets correctly
7. Cleanup: delete Forgejo secrets, disable AppRole

## Out of Scope

- Replacing DinD (`docker:27-dind`, `privileged: true`) — known security gap, separate ticket
- OpenTofu credentials for Proxmox API access — separate concern, separate ticket
- Forgejo Actions OIDC token federation — not supported in Forgejo 14.0.3
