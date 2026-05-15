# k3s-control-01

Single-node K3s control plane. Runs all cluster workloads managed by ArgoCD.

| | |
|---|---|
| **IP** | 192.168.1.60 |
| **OS** | Ubuntu 24.04 LTS (Noble) |
| **CPU / RAM** | 4 cores / 8 GB |
| **Disk** | 60 GB |
| **VM ID** | 110 |

## Manage this VM

**Provision (create/update the VM in Proxmox):**
```
cd vms/k3s-control-01/provision
tofu init
tofu plan
tofu apply
```

**Configure (install k3s, ArgoCD, MCP servers):**
```
ansible-playbook vms/k3s-control-01/k3s.yml
ansible-playbook vms/k3s-control-01/argocd.yml
ansible-playbook vms/k3s-control-01/mcp-servers.yml
```

**Access the cluster:**
```
KUBECONFIG=~/.kube/k3s-homelab.yaml kubectl get nodes
```

## Playbooks

| Playbook | Purpose |
|---|---|
| `k3s.yml` | Install K3s, fetch kubeconfig |
| `argocd.yml` | Install ArgoCD |
| `mcp-servers.yml` | Deploy MCP server containers |

## Workloads (managed by ArgoCD)

Kubernetes manifests live in `kubernetes/` at the repo root — see `argocd/apps/` for the ArgoCD Application CRs.

## Related decisions

- ADR-016: Infrastructure on Proxmox VMs, applications on K3s
- ADR-018: VM-centric repo structure
