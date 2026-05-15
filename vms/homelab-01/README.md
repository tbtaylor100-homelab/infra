# homelab-01

Bare-metal host running Forgejo and OpenBao. Not provisioned by OpenTofu — this is the foundational machine that everything else depends on, so it predates the OpenTofu setup (ADR-009, ADR-005).

| | |
|---|---|
| **IP** | 192.168.1.50 |
| **User** | root |
| **SSH port** | 2222 |

## Manage this VM

**Upgrade Forgejo:**
```
ansible-playbook vms/homelab-01/forgejo-upgrade.yml
```

**Reconfigure OpenBao JWT auth (for CI pipelines):**
```
ansible-playbook vms/homelab-01/openbao-auth-config.yml
```

## Related decisions

- ADR-005: OpenBao as secrets manager
- ADR-009: Forgejo on a dedicated VM
- ADR-010: Forgejo OIDC CI auth
- ADR-018: VM-centric repo structure
