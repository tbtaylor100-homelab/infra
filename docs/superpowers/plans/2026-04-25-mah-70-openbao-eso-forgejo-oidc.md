# MAH-70: OpenBao + ESO + Forgejo OIDC Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Eliminate all stored credentials from Forgejo CI by migrating to per-job Forgejo OIDC tokens for OpenBao authentication and deploying External Secrets Operator as foundational K8s secret infrastructure.

**Architecture:** Forgejo v15 issues short-lived OIDC JWTs per CI job; OpenBao JWT auth backend validates them against Forgejo's JWKS. ESO is deployed with a ClusterSecretStore using Kubernetes auth for future K8s app secrets. The forgejo-runner itself uses per-job OIDC tokens, not ESO.

**Tech Stack:** Ansible, OpenBao (Vault-compatible API), External Secrets Operator (Helm via ArgoCD), Forgejo v15, Forgejo Runner, K3s

---

## File Map

| File | Action | Purpose |
|------|--------|---------|
| `ansible/inventory/hosts.yml` | Modify | Add `homelab` VM (.50) host group |
| `ansible/roles/forgejo/defaults/main.yml` | Create | Forgejo version variable |
| `ansible/roles/forgejo/tasks/main.yml` | Create | Binary upgrade + service restart |
| `ansible/roles/forgejo/handlers/main.yml` | Create | Restart forgejo service on change |
| `ansible/playbooks/forgejo-upgrade.yml` | Create | Runs forgejo role against homelab |
| `ansible/playbooks/openbao-auth-config.yml` | Create | Configures Kubernetes + JWT auth backends in OpenBao |
| `ansible/inventory/group_vars/all/secrets.yml` | Modify | Add `openbao_root_token` (vault-encrypted) |
| `argocd/apps/external-secrets.yaml` | Create | ArgoCD Application for ESO Helm chart |
| `kubernetes/external-secrets/cluster-secret-store.yaml` | Create | ClusterSecretStore pointing at OpenBao |
| `kubernetes/forgejo-runner/deployment.yaml` | Modify | Pin runner image to Forgejo runner |
| `.forgejo/workflows/test-oidc.yml` | Create | Temporary — verifies OIDC token flow end-to-end |
| `.forgejo/workflows/tofu-plan.yml` | Modify | Replace AppRole block with OIDC auth |
| `.forgejo/workflows/tofu-apply.yml` | Modify | Replace AppRole block with OIDC auth (ci-apply role) |

---

## Task 1: Establish SSH access to the homelab VM

**Files:**
- Modify: `ansible/inventory/hosts.yml`

This is a manual prerequisite. The homelab VM (ID 102, `192.168.1.50`) has no SSH key for the system user yet.

- [ ] **Step 1: Confirm current state**

```bash
ssh ubuntu@192.168.1.50 'echo "SSH OK"'
```
Expected: `Permission denied (publickey)` — confirms key is not yet provisioned.

- [ ] **Step 2: Add your public key via Proxmox console**

Open `http://192.168.1.12:8006` in a browser. Select VM 102 (homelab) → Console. Log in with the VM password (check Proxmox notes or reset via console). Then run:

```bash
# On the homelab VM via Proxmox console — find the admin user first
cat /etc/passwd | grep -E 'bash|sh$' | grep -v nologin
# Likely ubuntu or a named user; run as that user:
mkdir -p ~/.ssh
echo "$(cat ~/.ssh/id_ed25519.pub)" >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
```

Run `cat ~/.ssh/id_ed25519.pub` on your Mac to get the key to paste.

- [ ] **Step 3: Verify SSH works**

```bash
ssh ubuntu@192.168.1.50 'echo "SSH OK && whoami"'
```
Expected: `SSH OK` and the username printed.

- [ ] **Step 4: Add homelab to Ansible inventory**

Edit `ansible/inventory/hosts.yml`:

```yaml
all:
  children:
    k3s:
      hosts:
        k3s-control-01:
          ansible_host: 192.168.1.60
          ansible_user: ubuntu
          ansible_ssh_private_key_file: ~/.ssh/id_ed25519
    uptime_kuma:
      hosts:
        uptime-kuma-01:
          ansible_host: 192.168.1.61
          ansible_user: ubuntu
          ansible_ssh_private_key_file: ~/.ssh/id_ed25519
    homelab:
      hosts:
        homelab-01:
          ansible_host: 192.168.1.50
          ansible_user: ubuntu
          ansible_ssh_private_key_file: ~/.ssh/id_ed25519
```

- [ ] **Step 5: Verify Ansible connectivity**

```bash
ansible homelab -i ansible/inventory/hosts.yml -m ping
```
Expected:
```
homelab-01 | SUCCESS => {"ping": "pong"}
```

- [ ] **Step 6: Commit**

```bash
git add ansible/inventory/hosts.yml
git commit -m "chore: add homelab VM to Ansible inventory"
```

---

## Task 2: Discover Forgejo install details

**Files:** (read-only — informs Tasks 3 and 4)

- [ ] **Step 1: Find the Forgejo binary**

```bash
ansible homelab -i ansible/inventory/hosts.yml -a "find /opt /usr/local/bin /home/git -name forgejo -type f 2>/dev/null"
```
Expected: a path such as `/opt/apps/forgejo/forgejo` or `/usr/local/bin/forgejo`.

- [ ] **Step 2: Check the systemd service**

```bash
ansible homelab -i ansible/inventory/hosts.yml -a "systemctl status forgejo"
```
Expected: service is `active (running)`. Note the `ExecStart=` path and the user (`User=` line).

- [ ] **Step 3: Note the current version**

```bash
ansible homelab -i ansible/inventory/hosts.yml -a "forgejo --version"
```
Expected: `Forgejo version 14.x.x ...`

Record the binary path, service name, and running user — you will need them in Task 3.

---

## Task 3: Create Forgejo Ansible role

**Files:**
- Create: `ansible/roles/forgejo/defaults/main.yml`
- Create: `ansible/roles/forgejo/tasks/main.yml`
- Create: `ansible/roles/forgejo/handlers/main.yml`
- Create: `ansible/playbooks/forgejo-upgrade.yml`

- [ ] **Step 1: Write the version verification test**

```bash
curl -s http://192.168.1.50:3000/api/v1/version | jq -r '.version'
```
Expected: `14.x.x+gitea-...` — confirms pre-upgrade state.

- [ ] **Step 2: Create role defaults**

Create `ansible/roles/forgejo/defaults/main.yml`:

```yaml
forgejo_version: "15.0.0"
forgejo_binary_path: "/opt/apps/forgejo/forgejo"
forgejo_service_name: "forgejo"
forgejo_user: "git"
forgejo_download_url: "https://codeberg.org/forgejo/forgejo/releases/download/v{{ forgejo_version }}/forgejo-{{ forgejo_version }}-linux-amd64"
```

Update `forgejo_binary_path` and `forgejo_user` with the values discovered in Task 2.

- [ ] **Step 3: Create role tasks**

Create `ansible/roles/forgejo/tasks/main.yml`:

```yaml
- name: Get current Forgejo version
  command: "{{ forgejo_binary_path }} --version"
  register: current_version
  changed_when: false

- name: Download Forgejo v{{ forgejo_version }} binary
  get_url:
    url: "{{ forgejo_download_url }}"
    dest: "/tmp/forgejo-{{ forgejo_version }}"
    mode: "0755"
  when: forgejo_version not in current_version.stdout

- name: Stop Forgejo service
  systemd:
    name: "{{ forgejo_service_name }}"
    state: stopped
  when: forgejo_version not in current_version.stdout

- name: Replace Forgejo binary
  copy:
    src: "/tmp/forgejo-{{ forgejo_version }}"
    dest: "{{ forgejo_binary_path }}"
    owner: "{{ forgejo_user }}"
    group: "{{ forgejo_user }}"
    mode: "0755"
    remote_src: true
  when: forgejo_version not in current_version.stdout
  notify: restart forgejo

- name: Start Forgejo service
  systemd:
    name: "{{ forgejo_service_name }}"
    state: started
    enabled: true
  when: forgejo_version not in current_version.stdout

- name: Wait for Forgejo API to be ready
  uri:
    url: "http://127.0.0.1:3000/api/v1/version"
    status_code: 200
  register: result
  until: result.status == 200
  retries: 12
  delay: 5
```

- [ ] **Step 4: Create role handler**

Create `ansible/roles/forgejo/handlers/main.yml`:

```yaml
- name: restart forgejo
  systemd:
    name: "{{ forgejo_service_name }}"
    state: restarted
```

- [ ] **Step 5: Create upgrade playbook**

Create `ansible/playbooks/forgejo-upgrade.yml`:

```yaml
- name: Upgrade Forgejo to v15
  hosts: homelab
  become: true
  roles:
    - forgejo
```

- [ ] **Step 6: Run dry-run check**

```bash
ansible-playbook -i ansible/inventory/hosts.yml ansible/playbooks/forgejo-upgrade.yml --check
```
Expected: no errors; task "Replace Forgejo binary" shown as would-change.

- [ ] **Step 7: Run upgrade**

```bash
ansible-playbook -i ansible/inventory/hosts.yml ansible/playbooks/forgejo-upgrade.yml
```
Expected: tasks complete, service restarted.

- [ ] **Step 8: Verify v15 is running**

```bash
curl -s http://192.168.1.50:3000/api/v1/version | jq -r '.version'
```
Expected: `15.0.0+...`

- [ ] **Step 9: Verify OIDC discovery endpoint**

```bash
curl -s http://192.168.1.50:3000/.well-known/openid-configuration | jq '.jwks_uri'
```
Expected: `"http://192.168.1.50:3000/login/oauth/keys"`

- [ ] **Step 10: Commit**

```bash
git add ansible/roles/forgejo/ ansible/playbooks/forgejo-upgrade.yml
git commit -m "feat: add Forgejo Ansible role + upgrade playbook to v15"
```

---

## Task 4: Deploy ESO via ArgoCD

**Files:**
- Create: `argocd/apps/external-secrets.yaml`

- [ ] **Step 1: Write the failing test**

```bash
kubectl get ns external-secrets 2>&1
```
Expected: `Error from server (NotFound): namespaces "external-secrets" not found`

- [ ] **Step 2: Create ArgoCD Application**

Create `argocd/apps/external-secrets.yaml`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: external-secrets
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://charts.external-secrets.io
    chart: external-secrets
    targetRevision: "0.14.0"
    helm:
      values: |
        serviceAccount:
          name: external-secrets
        crds:
          create: true
        webhook:
          create: false
        certController:
          create: false
  destination:
    server: https://kubernetes.default.svc
    namespace: external-secrets
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

- [ ] **Step 3: Commit and push — ArgoCD auto-syncs**

```bash
git add argocd/apps/external-secrets.yaml
git commit -m "feat: deploy External Secrets Operator via ArgoCD"
git push
```

- [ ] **Step 4: Watch ArgoCD sync**

```bash
kubectl get pods -n external-secrets -w
```
Expected within 2 minutes: `external-secrets-xxxx` pod in `Running` state.

- [ ] **Step 5: Verify CRDs installed**

```bash
kubectl get crds | grep external-secrets.io
```
Expected: at minimum `clustersecretstores.external-secrets.io` and `externalsecrets.external-secrets.io` listed.

---

## Task 5: Store OpenBao root token in Ansible vault

**Files:**
- Modify: `ansible/inventory/group_vars/all/secrets.yml`

The OpenBao Kubernetes and JWT auth backends are configured by running `bao` commands inside the OpenBao pod. The Ansible playbook needs the root token to authenticate.

- [ ] **Step 1: Retrieve root token**

The root token was generated during `bao operator init`. If stored as a K8s Secret:

```bash
kubectl get secret -n openbao -o name | grep root
# If found:
kubectl get secret -n openbao <name> -o jsonpath='{.data.token}' | base64 -d
```

If not in K8s, check your secure notes from the original OpenBao initialization.

- [ ] **Step 2: Add to Ansible vault**

```bash
cd ansible
ansible-vault edit inventory/group_vars/all/secrets.yml
```

Add this line to the encrypted file:

```yaml
openbao_root_token: "hvs.XXXXXXXXXXXXXXXXXXXXXXXX"
```

Replace the value with your actual root token.

- [ ] **Step 3: Verify vault decrypts**

```bash
ansible-vault view ansible/inventory/group_vars/all/secrets.yml | grep openbao_root_token
```
Expected: the token value printed (in your terminal only).

---

## Task 6: Write and run OpenBao auth config playbook

**Files:**
- Create: `ansible/playbooks/openbao-auth-config.yml`

The Ansible controller (your Mac) can reach OpenBao directly at `http://192.168.1.210:8200`. This playbook runs from `localhost` using Ansible's `uri` module — no `kubectl exec` needed.

- [ ] **Step 1: Write the failing test — confirm neither backend exists yet**

```bash
# Set ROOT_TOKEN from your vault secrets (same value stored in secrets.yml)
ROOT_TOKEN=$(ansible-vault view ansible/inventory/group_vars/all/secrets.yml --ask-vault-pass | grep openbao_root_token | awk '{print $2}')

curl -sf \
  --header "X-Vault-Token: $ROOT_TOKEN" \
  http://192.168.1.210:8200/v1/sys/auth | jq 'keys'
```
Expected: `["approle/", "token/"]` — no `kubernetes/` or `jwt/`.

- [ ] **Step 2: Create the playbook**

Create `ansible/playbooks/openbao-auth-config.yml`:

```yaml
- name: Configure OpenBao auth backends
  hosts: localhost
  connection: local
  gather_facts: false
  vars:
    openbao_addr: "http://192.168.1.210:8200"
    k3s_api: "https://192.168.1.60:6443"
    forgejo_jwks: "http://192.168.1.50:3000/login/oauth/keys"
    forgejo_issuer: "http://192.168.1.50:3000"
  vars_files:
    - ../inventory/group_vars/all/secrets.yml

  tasks:
    - name: Enable Kubernetes auth backend
      uri:
        url: "{{ openbao_addr }}/v1/sys/auth/kubernetes"
        method: POST
        headers:
          X-Vault-Token: "{{ openbao_root_token }}"
        body_format: json
        body:
          type: kubernetes
        status_code: [200, 204, 400]
      register: k8s_enable
      changed_when: k8s_enable.status in [200, 204]

    - name: Configure Kubernetes auth backend
      uri:
        url: "{{ openbao_addr }}/v1/auth/kubernetes/config"
        method: POST
        headers:
          X-Vault-Token: "{{ openbao_root_token }}"
        body_format: json
        body:
          kubernetes_host: "{{ k3s_api }}"
          disable_local_ca_jwt: false
        status_code: [200, 204]

    - name: Enable JWT auth backend
      uri:
        url: "{{ openbao_addr }}/v1/sys/auth/jwt"
        method: POST
        headers:
          X-Vault-Token: "{{ openbao_root_token }}"
        body_format: json
        body:
          type: jwt
        status_code: [200, 204, 400]
      register: jwt_enable
      changed_when: jwt_enable.status in [200, 204]

    - name: Configure JWT auth backend with Forgejo JWKS
      uri:
        url: "{{ openbao_addr }}/v1/auth/jwt/config"
        method: POST
        headers:
          X-Vault-Token: "{{ openbao_root_token }}"
        body_format: json
        body:
          jwks_url: "{{ forgejo_jwks }}"
          bound_issuer: "{{ forgejo_issuer }}"
        status_code: [200, 204]

    - name: Create ci-reader policy
      uri:
        url: "{{ openbao_addr }}/v1/sys/policies/acl/ci-reader"
        method: POST
        headers:
          X-Vault-Token: "{{ openbao_root_token }}"
        body_format: json
        body:
          policy: |
            path "secret/data/homelab/ci" {
              capabilities = ["read"]
            }
        status_code: [200, 204]

    - name: Create eso-policy
      uri:
        url: "{{ openbao_addr }}/v1/sys/policies/acl/eso-policy"
        method: POST
        headers:
          X-Vault-Token: "{{ openbao_root_token }}"
        body_format: json
        body:
          policy: |
            path "secret/data/homelab/ci" {
              capabilities = ["read"]
            }
        status_code: [200, 204]

    - name: Create Kubernetes auth role for ESO
      uri:
        url: "{{ openbao_addr }}/v1/auth/kubernetes/role/eso-reader"
        method: POST
        headers:
          X-Vault-Token: "{{ openbao_root_token }}"
        body_format: json
        body:
          bound_service_account_names:
            - external-secrets
          bound_service_account_namespaces:
            - external-secrets
          policies:
            - eso-policy
          ttl: "1h"
        status_code: [200, 204]

    - name: Create JWT role ci-plan (any branch, infra repo only)
      uri:
        url: "{{ openbao_addr }}/v1/auth/jwt/role/ci-plan"
        method: POST
        headers:
          X-Vault-Token: "{{ openbao_root_token }}"
        body_format: json
        body:
          role_type: jwt
          bound_audiences:
            - openbao
          bound_claims_type: glob
          bound_claims:
            repository:
              - root/infra
          user_claim: sub
          policies:
            - ci-reader
          ttl: "5m"
        status_code: [200, 204]

    - name: Create JWT role ci-apply (main branch only)
      uri:
        url: "{{ openbao_addr }}/v1/auth/jwt/role/ci-apply"
        method: POST
        headers:
          X-Vault-Token: "{{ openbao_root_token }}"
        body_format: json
        body:
          role_type: jwt
          bound_audiences:
            - openbao
          bound_claims_type: glob
          bound_claims:
            repository:
              - root/infra
            ref:
              - refs/heads/main
          user_claim: sub
          policies:
            - ci-reader
          ttl: "5m"
        status_code: [200, 204]
```

- [ ] **Step 3: Run the playbook**

```bash
ansible-playbook \
  -i ansible/inventory/hosts.yml \
  --ask-vault-pass \
  ansible/playbooks/openbao-auth-config.yml
```
Expected: all tasks green (changed or ok), no failures.

- [ ] **Step 4: Verify both backends are enabled**

```bash
ROOT_TOKEN=$(ansible-vault view ansible/inventory/group_vars/all/secrets.yml --ask-vault-pass | grep openbao_root_token | awk '{print $2}')

curl -sf \
  --header "X-Vault-Token: $ROOT_TOKEN" \
  http://192.168.1.210:8200/v1/sys/auth | jq 'keys'
```
Expected: `["approle/", "jwt/", "kubernetes/", "token/"]`

- [ ] **Step 5: Verify JWT roles exist**

```bash
curl -sf \
  --header "X-Vault-Token: $ROOT_TOKEN" \
  --request LIST \
  http://192.168.1.210:8200/v1/auth/jwt/role | jq '.data.keys'
```
Expected: `["ci-apply", "ci-plan"]`

- [ ] **Step 6: Verify K8s role for ESO**

```bash
curl -sf \
  --header "X-Vault-Token: $ROOT_TOKEN" \
  http://192.168.1.210:8200/v1/auth/kubernetes/role/eso-reader | jq '.data | {bound_service_account_names, policies}'
```
Expected:
```json
{
  "bound_service_account_names": ["external-secrets"],
  "policies": ["eso-policy"]
}
```

- [ ] **Step 7: Commit**

```bash
git add ansible/playbooks/openbao-auth-config.yml
git commit -m "feat: add OpenBao Kubernetes + JWT auth config playbook"
```

---

## Task 7: Create ClusterSecretStore

**Files:**
- Create: `kubernetes/external-secrets/cluster-secret-store.yaml`

- [ ] **Step 1: Write the failing test**

```bash
kubectl get clustersecretstore 2>&1
```
Expected: `No resources found` or CRD not found error.

- [ ] **Step 2: Create ClusterSecretStore**

Create `kubernetes/external-secrets/cluster-secret-store.yaml`:

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
          serviceAccountRef:
            name: "external-secrets"
            namespace: "external-secrets"
```

- [ ] **Step 3: Apply and verify**

```bash
kubectl apply -f kubernetes/external-secrets/cluster-secret-store.yaml
kubectl get clustersecretstore openbao -o jsonpath='{.status.conditions}' | jq .
```
Expected: condition with `type: Ready, status: "True"`.

If status shows `reason: VaultError`, the Kubernetes auth role is misconfigured — re-check Task 6 step 4.

- [ ] **Step 4: Commit**

```bash
git add kubernetes/external-secrets/cluster-secret-store.yaml
git commit -m "feat: add OpenBao ClusterSecretStore for ESO"
```

---

## Task 8: Pin runner to Forgejo runner image

**Files:**
- Modify: `kubernetes/forgejo-runner/deployment.yaml`

The current image is `gitea/act_runner:latest`. Forgejo OIDC token support requires the Forgejo runner image.

- [ ] **Step 1: Write the failing test**

```bash
kubectl exec -n forgejo-runner deployment/forgejo-runner -c runner -- \
  env | grep ACTIONS_ID_TOKEN_REQUEST_URL
```
Expected: empty — env var not present yet.

- [ ] **Step 2: Update runner container image**

In `kubernetes/forgejo-runner/deployment.yaml`, change the `runner` and `register` init container images from `gitea/act_runner:latest` to `code.forgejo.org/forgejo/runner:6.0.0`:

```yaml
      initContainers:
        - name: register
          image: code.forgejo.org/forgejo/runner:6.0.0
          # ... rest unchanged
      containers:
        - name: runner
          image: code.forgejo.org/forgejo/runner:6.0.0
          # ... rest unchanged
```

Verify the correct tag at https://codeberg.org/forgejo/runner/releases — use the latest stable release that is v12.5.0 API-compatible (v6.x as of 2026).

- [ ] **Step 3: Commit — ArgoCD reconciles**

```bash
git add kubernetes/forgejo-runner/deployment.yaml
git commit -m "feat: pin forgejo-runner to Forgejo runner image for OIDC support"
git push
```

- [ ] **Step 4: Verify pod restarts with new image**

```bash
kubectl rollout status deployment/forgejo-runner -n forgejo-runner
kubectl get pods -n forgejo-runner -o jsonpath='{.items[0].spec.containers[0].image}'
```
Expected: `code.forgejo.org/forgejo/runner:6.0.0`

---

## Task 9: Validate OIDC token flow end-to-end

**Files:**
- Create: `.forgejo/workflows/test-oidc.yml` (temporary — deleted in Task 12)

- [ ] **Step 1: Create test workflow**

Create `.forgejo/workflows/test-oidc.yml`:

```yaml
name: Test Forgejo OIDC

on:
  push:
    branches:
      - 'test/oidc-*'

permissions:
  id-token: write
  contents: read

jobs:
  test-oidc:
    runs-on: ubuntu-latest
    steps:
      - name: Request Forgejo OIDC token
        run: |
          echo "TOKEN_URL: $ACTIONS_ID_TOKEN_REQUEST_URL"
          if [ -z "$ACTIONS_ID_TOKEN_REQUEST_URL" ]; then
            echo "ERROR: ACTIONS_ID_TOKEN_REQUEST_URL not set — runner does not support OIDC"
            exit 1
          fi

          OIDC_TOKEN=$(curl -sf \
            -H "Authorization: bearer $ACTIONS_ID_TOKEN_REQUEST_TOKEN" \
            "${ACTIONS_ID_TOKEN_REQUEST_URL}&audience=openbao" | jq -r '.value')

          if [ -z "$OIDC_TOKEN" ] || [ "$OIDC_TOKEN" = "null" ]; then
            echo "ERROR: Failed to obtain OIDC token"
            exit 1
          fi

          echo "OIDC token obtained (length: ${#OIDC_TOKEN})"

          # Decode and print claims (not the token itself)
          echo "$OIDC_TOKEN" | cut -d. -f2 | base64 -d 2>/dev/null | jq '{iss, sub, repository, ref, workflow}'

      - name: Exchange OIDC token for OpenBao token
        run: |
          OIDC_TOKEN=$(curl -sf \
            -H "Authorization: bearer $ACTIONS_ID_TOKEN_REQUEST_TOKEN" \
            "${ACTIONS_ID_TOKEN_REQUEST_URL}&audience=openbao" | jq -r '.value')

          RESPONSE=$(curl -sf --request POST \
            --header "Content-Type: application/json" \
            --data "{\"jwt\":\"$OIDC_TOKEN\",\"role\":\"ci-plan\"}" \
            http://192.168.1.210:8200/v1/auth/jwt/login)

          BAO_TOKEN=$(echo "$RESPONSE" | jq -r '.auth.client_token')

          if [ -z "$BAO_TOKEN" ] || [ "$BAO_TOKEN" = "null" ]; then
            echo "ERROR: OpenBao JWT login failed"
            echo "$RESPONSE" | jq .
            exit 1
          fi

          echo "OpenBao token obtained successfully"

      - name: Read a non-sensitive secret from OpenBao
        run: |
          OIDC_TOKEN=$(curl -sf \
            -H "Authorization: bearer $ACTIONS_ID_TOKEN_REQUEST_TOKEN" \
            "${ACTIONS_ID_TOKEN_REQUEST_URL}&audience=openbao" | jq -r '.value')

          BAO_TOKEN=$(curl -sf --request POST \
            --header "Content-Type: application/json" \
            --data "{\"jwt\":\"$OIDC_TOKEN\",\"role\":\"ci-plan\"}" \
            http://192.168.1.210:8200/v1/auth/jwt/login | jq -r '.auth.client_token')

          PROXMOX_ENDPOINT=$(curl -sf \
            --header "X-Vault-Token: $BAO_TOKEN" \
            http://192.168.1.210:8200/v1/secret/data/homelab/ci \
            | jq -r '.data.data.proxmox_endpoint')

          if [ -z "$PROXMOX_ENDPOINT" ] || [ "$PROXMOX_ENDPOINT" = "null" ]; then
            echo "ERROR: Failed to read proxmox_endpoint from OpenBao"
            exit 1
          fi

          echo "Successfully read proxmox_endpoint: $PROXMOX_ENDPOINT"
```

- [ ] **Step 2: Push to a test branch and watch CI**

```bash
git add .forgejo/workflows/test-oidc.yml
git commit -m "test: add OIDC validation workflow (temporary)"
git checkout -b test/oidc-validate
git push origin test/oidc-validate
```

Open `http://192.168.1.50:3000` → infra repo → Actions. Watch the `Test Forgejo OIDC` workflow run.

- [ ] **Step 3: Confirm all three steps pass**

Expected output for step "Request Forgejo OIDC token":
```
TOKEN_URL: https://192.168.1.50:3000/...
OIDC token obtained (length: 500+)
{
  "iss": "http://192.168.1.50:3000",
  "sub": "...",
  "repository": "root/infra",
  "ref": "refs/heads/test/oidc-validate"
}
```

If `ACTIONS_ID_TOKEN_REQUEST_URL` is empty: the runner image does not support OIDC. Check https://codeberg.org/forgejo/runner/releases for the correct version and update `deployment.yaml`.

If OpenBao returns a 403: re-check the JWT role `bound_claims` in Task 6 — the `repository` claim must match exactly.

---

## Task 10: Update tofu-plan.yml to use OIDC

**Files:**
- Modify: `.forgejo/workflows/tofu-plan.yml`

- [ ] **Step 1: Replace the AppRole fetch block**

In `.forgejo/workflows/tofu-plan.yml`, replace the entire `Fetch secrets from OpenBao` step (lines 20–56) with:

```yaml
      - name: Fetch secrets from OpenBao via Forgejo OIDC
        run: |
          # Request per-job OIDC token from Forgejo
          OIDC_TOKEN=$(curl -sf \
            -H "Authorization: bearer $ACTIONS_ID_TOKEN_REQUEST_TOKEN" \
            "${ACTIONS_ID_TOKEN_REQUEST_URL}&audience=openbao" | jq -r '.value')

          # Exchange OIDC token for OpenBao token
          BAO_TOKEN=$(curl -sf --request POST \
            --header "Content-Type: application/json" \
            --data "{\"jwt\":\"$OIDC_TOKEN\",\"role\":\"ci-plan\"}" \
            http://192.168.1.210:8200/v1/auth/jwt/login | jq -r '.auth.client_token')

          # Read all CI secrets in one call
          SECRETS=$(curl -sf \
            --header "X-Vault-Token: $BAO_TOKEN" \
            http://192.168.1.210:8200/v1/secret/data/homelab/ci | jq -r '.data.data')

          PROXMOX_ENDPOINT=$(echo "$SECRETS"    | jq -r '.proxmox_endpoint')
          PROXMOX_API_TOKEN=$(echo "$SECRETS"   | jq -r '.proxmox_api_token')
          SSH_PUBLIC_KEY=$(echo "$SECRETS"      | jq -r '.ssh_public_key')
          SSH_PRIVATE_KEY=$(echo "$SECRETS"     | jq -r '.ssh_private_key')
          MINIO_ACCESS_KEY=$(echo "$SECRETS"    | jq -r '.minio_access_key')
          MINIO_SECRET_KEY=$(echo "$SECRETS"    | jq -r '.minio_secret_key')

          echo "::add-mask::$PROXMOX_API_TOKEN"
          echo "::add-mask::$SSH_PRIVATE_KEY"
          echo "::add-mask::$MINIO_ACCESS_KEY"
          echo "::add-mask::$MINIO_SECRET_KEY"

          {
            echo "TF_VAR_proxmox_endpoint=$PROXMOX_ENDPOINT"
            echo "TF_VAR_proxmox_api_token=$PROXMOX_API_TOKEN"
            echo "TF_VAR_ssh_public_key=$SSH_PUBLIC_KEY"
            echo "AWS_ACCESS_KEY_ID=$MINIO_ACCESS_KEY"
            echo "AWS_SECRET_ACCESS_KEY=$MINIO_SECRET_KEY"
            printf 'TF_VAR_ssh_private_key<<__EOF__\n%s\n__EOF__\n' "$SSH_PRIVATE_KEY"
          } >> $GITHUB_ENV
```

Also add the `permissions` block at the job level (after `runs-on`):

```yaml
    permissions:
      id-token: write
      contents: read
```

- [ ] **Step 2: Commit and open a test PR**

```bash
git add .forgejo/workflows/tofu-plan.yml
git commit -m "feat: migrate tofu-plan to Forgejo OIDC auth for OpenBao"
git checkout -b feat/mah-70-oidc-ci
git push origin feat/mah-70-oidc-ci
```

Open a PR in Forgejo. The `OpenTofu Plan` workflow must complete successfully.

- [ ] **Step 3: Confirm secrets were read**

In the CI log for "Fetch secrets from OpenBao via Forgejo OIDC", confirm:
- No error output
- Subsequent `tofu plan` step shows Proxmox state (proves `TF_VAR_proxmox_api_token` was set)
- No `OPENBAO_ROLE_ID` or `OPENBAO_SECRET_ID` references anywhere in the log

---

## Task 11: Update tofu-apply.yml to use OIDC

**Files:**
- Modify: `.forgejo/workflows/tofu-apply.yml`

- [ ] **Step 1: Replace the AppRole fetch block**

Apply the identical change from Task 10 to `.forgejo/workflows/tofu-apply.yml`, with one difference: use role `ci-apply` instead of `ci-plan`:

```yaml
            --data "{\"jwt\":\"$OIDC_TOKEN\",\"role\":\"ci-apply\"}" \
```

Also add the `permissions` block to this job:

```yaml
    permissions:
      id-token: write
      contents: read
```

- [ ] **Step 2: Commit to the same branch**

```bash
git add .forgejo/workflows/tofu-apply.yml
git commit -m "feat: migrate tofu-apply to Forgejo OIDC auth for OpenBao"
git push origin feat/mah-70-oidc-ci
```

- [ ] **Step 3: Merge the PR and verify apply runs**

Merge the PR from Task 10 to `main`. The `OpenTofu Apply` workflow triggers. Confirm it completes successfully — this exercises the `ci-apply` role on `refs/heads/main`.

---

## Task 12: Verify branch restriction enforcement

This test verifies that the `ci-apply` role correctly rejects tokens from non-main branches.

- [ ] **Step 1: Create a test branch that manually triggers apply**

```bash
git checkout -b test/verify-branch-restriction
```

Temporarily edit `.forgejo/workflows/tofu-apply.yml` to trigger on `push` to the test branch (add to the `branches` list). Push.

- [ ] **Step 2: Confirm rejection**

In the CI log for the apply workflow on this branch, the "Fetch secrets from OpenBao via Forgejo OIDC" step must fail with a 403 from OpenBao — not a Proxmox or Tofu error. The error message will be:
```
{"errors":["permission denied"]}
```

- [ ] **Step 3: Revert test change and delete branch**

```bash
git checkout main
git branch -D test/verify-branch-restriction
git push origin --delete test/verify-branch-restriction
```

---

## Task 13: Cleanup

- [ ] **Step 1: Delete Forgejo repo secrets**

In Forgejo UI: `http://192.168.1.50:3000/root/infra/settings` → Secrets. Delete:
- `OPENBAO_ROLE_ID`
- `OPENBAO_SECRET_ID`

Confirm they are gone from the secrets list.

- [ ] **Step 2: Verify CI still works without the secrets**

Trigger a dummy PR (whitespace change in `opentofu/`). Confirm `tofu-plan.yml` completes — proves it no longer depends on the deleted secrets.

- [ ] **Step 3: Disable AppRole in OpenBao**

```bash
kubectl exec -n openbao openbao-0 -- \
  env VAULT_TOKEN=<root-token> bao auth disable approle
```
Expected: `Success! Disabled the auth method at: approle/`

- [ ] **Step 4: Verify AppRole is gone**

```bash
kubectl exec -n openbao openbao-0 -- \
  env VAULT_TOKEN=<root-token> bao auth list
```
Expected: `approle/` no longer listed.

- [ ] **Step 5: Delete test workflow**

```bash
git rm .forgejo/workflows/test-oidc.yml
git checkout -b chore/mah-70-cleanup
git commit -m "chore: remove OIDC test workflow, disable AppRole"
git push origin chore/mah-70-cleanup
```

Open and merge a cleanup PR.

- [ ] **Step 6: Final verification**

```bash
# ESO ClusterSecretStore healthy
kubectl get clustersecretstore openbao -o jsonpath='{.status.conditions[0].status}'
# Expected: True

# Both JWT auth backends present, AppRole gone
kubectl exec -n openbao openbao-0 -- \
  env VAULT_TOKEN=<root-token> bao auth list | grep -E 'kubernetes|jwt|approle'
# Expected: kubernetes/ and jwt/ present, approle/ absent

# CI runs without stored secrets
curl -s http://192.168.1.50:3000/root/infra/settings  # secrets page empty of OPENBAO_* keys
```
