# VM Provisioning

How to provision a new VM and complete its setup.

## Steps

### 1. Apply OpenTofu

```bash
cd opentofu/stacks/<stack>
tofu apply -var-file=terraform.tfvars.secrets
```

OpenTofu creates the VM with hardware config (CPU, RAM, disk, network) and
seeds the SSH key. The VM is reachable via SSH after this step.

### 2. Run Ansible

```bash
cd ansible
ansible-playbook playbooks/<playbook>.yml -i inventory/hosts.yml --ask-vault-pass
```

Ansible installs packages (including `qemu-guest-agent`), hardens SSH, and
applies any role-specific configuration.

## Do not use cloud-init vendor_data

The `proxmox-vm` module does not use a `vendor_data` snippet and must never
have one added. Reasons:

- It violates the OpenTofu/Ansible separation — OS config belongs in Ansible,
  not in infrastructure code (see [ADR-004](../../../homelab-knowledge/adr/ADR-004-opentofu-ansible-layer-separation.md))
- Any change to snippet content forces destruction and recreation of the VM,
  causing Proxmox to assign a new MAC address and breaking router DHCP
  reservations

If you need something installed or configured on first boot, add it to the
appropriate Ansible role and run the playbook after `tofu apply`.
