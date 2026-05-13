# Phase 1: Secrets & Prerequisites - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-05-12
**Phase:** 1-Secrets & Prerequisites
**Areas discussed:** Policy HCL tracking, OpenBao field naming, Runbook depth

---

## Policy HCL tracking

| Option | Description | Selected |
|--------|-------------|----------|
| `kubernetes/external-secrets/eso-policy.hcl` | File committed to infra repo next to `cluster-secret-store.yaml`; applied with `bao policy write` | ✓ |
| `openbao/policies/eso-policy.hcl` | New top-level directory for OpenBao config | |
| Runbook-only (no file) | Policy HCL embedded inline in runbook markdown | |

**User's choice:** `kubernetes/external-secrets/eso-policy.hcl`
**Notes:** User initially asked about `opentofu/policies/` but correctly identified that OpenTofu manages VMs, not the k3s cluster — policy is ESO-related, not OpenTofu-related. `kubernetes/external-secrets/` is the right home because `cluster-secret-store.yaml` already lives there.

User also clarified that the provisioning runbook should live in `homelab-knowledge/runbooks/` (not `.planning/runbooks/`), because `.planning/` is project scaffolding that can be overwritten, while `homelab-knowledge` is the long-term operational knowledge base.

---

## OpenBao field naming

| Option | Description | Selected |
|--------|-------------|----------|
| Env var names (`SECRET_KEY`, `FORCED_SERVICE_CREDENTIALS`) | Field names match what the workload expects; ESO is a pass-through | ✓ |
| Lowercase snake_case (`secret_key`, `rd_api_key`) | Idiomatic OpenBao convention; ESO does remapping | |

**User's choice:** Env var names
**Notes:** User questioned whether this needed to be a cross-repo standard (and potentially ADR-016). Resolved: the PATH convention (`secret/<app>/<env>`) is already the standard; field names are owned by the service and don't require a separate homelab-wide rule. ADR-016 is not needed for this. AIOStreams uses `SECRET_KEY` and `FORCED_SERVICE_CREDENTIALS` because that's what the workload expects.

---

## Runbook depth

| Option | Description | Selected |
|--------|-------------|----------|
| Prominent SECRET_KEY immutability warning | Clear callout that SECRET_KEY cannot be changed after first use | ✓ |
| Inline comment only | Mention immutability next to the openssl command, no special callout | |
| Include RD API key source URL | Runbook documents where to get the Real-Debrid API key | ✓ |
| Assume operator knows | Skip the source instruction | |
| Include troubleshooting table | Common failures: sealed OpenBao, permission denied, ESO sync failure | ✓ |
| Commands only | No troubleshooting section | |
| Both steps in one runbook | Policy application + secret creation in one doc | |
| Policy step thin (references .hcl file) | Runbook focuses on secret creation; policy is a one-liner | ✓ |

**User's choice:** Comprehensive runbook with prominent immutability warning, RD API key URL, troubleshooting table; policy step is a thin one-liner referencing the committed .hcl file.
**Notes:** User's framing: "A runbook is for things that may need to be repeated. The HCL doesn't require changing much beyond initial setup." This means the runbook's heart is secret creation (repeatable), not policy management (one-time setup).

---

## Claude's Discretion

- Exact HCL content of `eso-policy.hcl` (must preserve the existing `secret/data/homelab/ci` path and add `secret/data/aiostreams/*`)
- `bao kv put` vs `bao kv patch` for initial secret creation

## Deferred Ideas

- ADR-016 for OpenBao field naming convention: discussed and resolved as unnecessary — path convention is already the standard, field names are service-owned.
