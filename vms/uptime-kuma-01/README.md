# uptime-kuma-01

Dedicated VM for Uptime Kuma — homelab uptime and health monitoring dashboard.
Runs on a Proxmox VM rather than K3s because monitoring must remain available during cluster outages (ADR-016).

| | |
|---|---|
| **IP** | 192.168.1.61 |
| **OS** | Ubuntu 24.04 LTS (Noble) |
| **CPU / RAM** | 1 core / 2 GB |
| **Disk** | 20 GB |
| **VM ID** | 111 |

## Manage this VM

**Provision (create/update the VM in Proxmox):**
```
cd vms/uptime-kuma-01/provision
tofu init
tofu plan
tofu apply
```

**Configure (install Uptime Kuma):**
```
ansible-playbook vms/uptime-kuma-01/uptime-kuma.yml
```

## Related decisions

- ADR-016: Infrastructure on Proxmox VMs, applications on K3s
- ADR-018: VM-centric repo structure
