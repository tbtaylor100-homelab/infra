# infra

Infrastructure-as-code for the homelab. All Proxmox VM provisioning, OS configuration, and ArgoCD app registrations live here.

## What's here

| Directory | Tool | Purpose |
|-----------|------|---------|
| `opentofu/modules/proxmox-vm/` | OpenTofu | Reusable VM blueprint for any Proxmox VM |
| `opentofu/stacks/k3s/` | OpenTofu | K3s control plane VM (VM 110, `k3s-control-01`) |
| `ansible/roles/base/` | Ansible | OS hardening, SSH config, unattended-upgrades |
| `ansible/roles/k3s/` | Ansible | K3s installation and configuration |
| `ansible/roles/argocd/` | Ansible | One-time ArgoCD bootstrap via Helm |
| `ansible/playbooks/` | Ansible | Playbooks that combine roles |
| `argocd/apps/` | ArgoCD | Application CRDs — one file per registered app |
| `.forgejo/workflows/` | Forgejo Actions | CI: `tofu plan` on PRs, `tofu apply` on merge |

## How changes work

1. Open a PR — CI runs `tofu fmt`, `tofu validate`, `tofu plan`, and `ansible-lint`
2. Merge to `main` — CI runs `tofu apply` and verifies K3s node is Ready
3. Adding a new K8s service: add an ArgoCD Application CRD to `argocd/apps/` — ArgoCD reconciles automatically

## What does NOT live here

Helm charts for individual apps. Each app has its own Forgejo repo containing its own chart. This repo only contains the ArgoCD pointer CRDs that tell ArgoCD where to find each app.

## Related

- JIRA Epic: MAHHAUS-42
- Plans: [homelab-plans/epic-1-homelab-platform-iac.md](http://192.168.1.50:3000/root/homelab-plans)
