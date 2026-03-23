## What

<!-- What does this PR change? Be specific: which VM, which role, which workflow. -->

## Why

<!-- Why is this change needed? Link to the JIRA story if applicable. -->

## Key decisions

<!-- Any tool choices, provider selections, or architectural decisions made in this PR.
     For each: what did you choose, what were the alternatives, and why this one?
     Example:
       - Using bpg/proxmox over Telmate/proxmox: bpg is actively maintained and has
         reliable cloud-init support; Telmate has known bugs with cloud-init networking. -->

## Type of change

- [ ] OpenTofu (VM provisioning)
- [ ] Ansible (OS/K3s configuration)
- [ ] ArgoCD app registration
- [ ] CI workflow
- [ ] Documentation / structure

## Pre-merge checklist

- [ ] `tofu fmt` passes locally
- [ ] `tofu validate` passes locally
- [ ] `ansible-lint` passes locally (if Ansible changed)
- [ ] No secrets or state files committed
- [ ] JIRA story updated

## Related

<!-- JIRA: MAHHAUS-XX -->
<!-- Depends on PR: # -->
