# Phase 1: Secrets & Prerequisites - Research

**Researched:** 2026-05-12
**Domain:** OpenBao KV v2, policy HCL, bao CLI, operational runbook authoring
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- **D-01:** The updated `eso-policy` HCL is committed to the infra repo at `kubernetes/external-secrets/eso-policy.hcl` alongside `cluster-secret-store.yaml`. This is the file that `bao policy write` reads. The policy is applied manually once; the file is the durable record.
- **D-02:** The runbook documents the `bao policy write` command as a thin one-liner referencing the file path, not a full walkthrough. Policy changes are infrequent and the file speaks for itself.
- **D-03:** Field names in `secret/aiostreams/production` match the env var names the workload expects: `SECRET_KEY` and `FORCED_SERVICE_CREDENTIALS`. No remapping in the ExternalSecret is needed.
- **D-04:** The provisioning runbook lives at `homelab-knowledge/runbooks/provision-aiostreams-secrets.md` — not `.planning/runbooks/`. `.planning/` is project scaffolding; operational runbooks belong in `homelab-knowledge` alongside ADRs.
- **D-05:** Runbook structure follows the existing format in `homelab-knowledge/runbooks/`:
  - Prerequisites (OpenBao reachable, root/admin token in hand)
  - Step 1: Apply eso-policy (one-liner: `bao policy write eso-policy kubernetes/external-secrets/eso-policy.hcl`) + verify with `bao policy show`
  - Step 2: Generate `SECRET_KEY` via `openssl rand -hex 32` — prominent immutability warning
  - Step 3: Create secret at `secret/aiostreams/production` with both fields in one `bao kv put`
  - Step 4: Verify with `bao kv get secret/aiostreams/production`
  - Troubleshooting table matching `add-credential.md` format

### Claude's Discretion

- Exact HCL content of `eso-policy.hcl` (must include both the existing `secret/data/homelab/ci` path and the new `secret/data/aiostreams/*` path — verify against current policy before writing)
- Whether to use `bao kv put` or `bao kv patch` for initial secret creation (either is fine; `put` is simpler for a net-new path)

### Deferred Ideas (OUT OF SCOPE)

- ADR-016 for OpenBao field naming convention: resolved as a non-issue. No separate ADR needed.

</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| INFRA-01 | OpenBao `eso-policy` extended to grant read access to `secret/data/aiostreams/*` | Verified current policy scope from `openbao-auth-config.yml`; HCL syntax confirmed from existing playbook |
| INFRA-02 | AIOStreams `SECRET_KEY` (64-char hex) generated and stored immutably in OpenBao at `secret/aiostreams/production` | `bao kv put` syntax and KV v2 path conventions verified from existing runbooks |
| INFRA-03 | Real-Debrid API key stored in OpenBao at `secret/aiostreams/production` as `FORCED_SERVICE_CREDENTIALS=realdebrid.apiKey=<key>` | Same `bao kv put` command covers both fields atomically |
| INFRA-04 | Secret provisioning runbook documents exact `bao kv put` commands, policy HCL, and `openssl rand -hex 32` generation step | Runbook format extracted from `add-credential.md`; exact structure defined in D-05 |

</phase_requirements>

---

## Summary

Phase 1 is a pure infrastructure-provisioning phase with no Kubernetes manifests. All work falls into three buckets: (1) author and commit an HCL policy file to the infra repo, (2) run `bao` CLI commands against the live OpenBao instance to apply the policy and write the secrets, and (3) author and commit a runbook markdown file to the `homelab-knowledge` repo.

The current `eso-policy` covers exactly one path: `secret/data/homelab/ci` with `["read"]` capability. This is verified directly in `ansible/playbooks/openbao-auth-config.yml` which created the policy. The `eso-reader` Kubernetes auth role binds the `external-secrets` ServiceAccount in the `external-secrets` namespace to this policy. Phase 1 extends the policy to also cover `secret/data/aiostreams/*`, then provisions the two required secret fields at `secret/aiostreams/production`.

The `homelab-knowledge` repo is a sibling repo at `C:\repos\homelab-knowledge` (separate git history from `C:\repos\infra`). Writing the runbook requires a commit to that repo. The infra repo commit covers only `kubernetes/external-secrets/eso-policy.hcl`. These are two distinct git operations.

**Primary recommendation:** Three sequential tasks — (1) write and commit `eso-policy.hcl` to infra repo, (2) provision secrets in OpenBao via `bao` CLI, (3) write and commit the runbook to `homelab-knowledge`. Tasks 1 and 3 are file-authoring tasks; task 2 is a live-system operation that requires OpenBao to be unsealed.

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Policy HCL authoring | Operator workstation (file creation) | OpenBao (policy enforcement) | File is the durable record; OpenBao applies it at `bao policy write` time |
| Secret provisioning | OpenBao (KV v2 storage) | — | `bao kv put` writes directly to the secrets backend; no K8s involvement in Phase 1 |
| ESO auth binding | OpenBao (Kubernetes auth backend) | k3s (ServiceAccount) | `eso-reader` role binds SA token to policy; already configured, no changes needed in Phase 1 |
| Runbook documentation | homelab-knowledge repo | — | Operational runbooks live alongside ADRs in the knowledge repo, not in the infra repo |

---

## Standard Stack

### Core

| Tool | Version | Purpose | Why Standard |
|------|---------|---------|--------------|
| `bao` CLI | Compatible with OpenBao at `http://192.168.1.210:8200` | All OpenBao operations (policy write, kv put, kv get) | Established homelab tool; used in all existing runbooks [VERIFIED: runbooks] |
| OpenBao KV v2 | In use (ClusterSecretStore `version: v2`) | Secret storage backend | Already deployed; ESO ClusterSecretStore is pre-configured to v2 [VERIFIED: cluster-secret-store.yaml] |
| `openssl` | System-installed | Generate `SECRET_KEY` via `openssl rand -hex 32` | Standard POSIX tool; produces cryptographically random 64-char hex [ASSUMED] |

### No Additional Libraries Required

Phase 1 involves no new software installation. All tools (`bao`, `openssl`) are already available in the environment. [VERIFIED: existing runbooks use these tools without installation steps]

---

## Architecture Patterns

### System Architecture Diagram

```
Operator workstation
      |
      |-- git commit --> infra repo (C:\repos\infra)
      |                  └── kubernetes/external-secrets/eso-policy.hcl  [NEW FILE]
      |
      |-- bao policy write --> OpenBao (http://192.168.1.210:8200)
      |                         └── eso-policy updated
      |                              ├── secret/data/homelab/ci [EXISTING]
      |                              └── secret/data/aiostreams/* [NEW]
      |
      |-- bao kv put --> OpenBao KV v2
      |                   └── secret/aiostreams/production
      |                        ├── SECRET_KEY = <64-char hex>
      |                        └── FORCED_SERVICE_CREDENTIALS = realdebrid.apiKey=<key>
      |
      |-- git commit --> homelab-knowledge repo (C:\repos\homelab-knowledge)
                         └── runbooks/provision-aiostreams-secrets.md  [NEW FILE]

                                        ↓ Phase 2 dependency
                         ESO (external-secrets namespace)
                              └── ClusterSecretStore/openbao
                                   └── ExternalSecret reads secret/aiostreams/production
                                        (will work once policy covers that path)
```

### Recommended Project Structure

Two repos touched by this phase:

```
C:\repos\infra\
└── kubernetes/
    └── external-secrets/
        ├── cluster-secret-store.yaml  [EXISTING — do not modify]
        └── eso-policy.hcl             [NEW — create this file]

C:\repos\homelab-knowledge\
└── runbooks/
    ├── add-credential.md              [EXISTING — format reference]
    ├── provision-app-secrets.md       [EXISTING — do not modify]
    └── provision-aiostreams-secrets.md [NEW — create this file]
```

### Pattern 1: OpenBao KV v2 — CLI vs API Path Syntax

**What:** KV v2 has a split between CLI syntax and HTTP API path syntax. Getting this wrong produces confusing errors.

**When to use:** Every `bao kv` command and every policy HCL block.

```bash
# Source: verified from existing runbooks (provision-app-secrets.md, add-credential.md)

# CLI commands use the mount prefix WITHOUT /data/
bao kv put -address=http://192.168.1.210:8200 secret/aiostreams/production \
  SECRET_KEY=<value> \
  FORCED_SERVICE_CREDENTIALS=realdebrid.apiKey=<value>

bao kv get -address=http://192.168.1.210:8200 secret/aiostreams/production

# Policy HCL uses the mount prefix WITH /data/ (API path)
path "secret/data/aiostreams/*" {
  capabilities = ["read", "list"]
}
```

**The rule:** `bao kv` subcommands prepend `/data/` automatically. The policy HCL must match the HTTP API path (which includes `/data/`).

### Pattern 2: eso-policy.hcl — Full File Content

**What:** The HCL file must preserve the existing path AND add the new one.

**Verified existing scope from `openbao-auth-config.yml`:**

```hcl
# Source: verified from ansible/playbooks/openbao-auth-config.yml lines 83-86
# Current eso-policy content (as provisioned by Ansible):
path "secret/data/homelab/ci" {
  capabilities = ["read"]
}
```

**Required final content of `kubernetes/external-secrets/eso-policy.hcl`:**

```hcl
# Source: existing path from openbao-auth-config.yml + new path per INFRA-01
path "secret/data/homelab/ci" {
  capabilities = ["read"]
}

path "secret/data/aiostreams/*" {
  capabilities = ["read", "list"]
}
```

**Apply command (run from repo root):**

```bash
bao policy write -address=http://192.168.1.210:8200 eso-policy kubernetes/external-secrets/eso-policy.hcl
```

**Verify:**

```bash
bao policy show -address=http://192.168.1.210:8200 eso-policy
# or: bao policy read -address=http://192.168.1.210:8200 eso-policy
```

### Pattern 3: Secret Provisioning — Single Atomic Write

**What:** Both fields written in a single `bao kv put` command to avoid partial state.

```bash
# Source: pattern from provision-app-secrets.md; field names from INFRA-02/INFRA-03

# Step 1: Generate SECRET_KEY (run and capture immediately)
SECRET_KEY=$(openssl rand -hex 32)
echo "SECRET_KEY=$SECRET_KEY"  # record before proceeding

# Step 2: Write both fields atomically
bao kv put -address=http://192.168.1.210:8200 secret/aiostreams/production \
  SECRET_KEY="$SECRET_KEY" \
  FORCED_SERVICE_CREDENTIALS="realdebrid.apiKey=<YOUR_RD_KEY>"

# Step 3: Verify
bao kv get -address=http://192.168.1.210:8200 secret/aiostreams/production
```

**FORCED_SERVICE_CREDENTIALS value:** The full string stored in OpenBao is `realdebrid.apiKey=<key>`, not just `<key>`. The RD API token is retrieved from `https://real-debrid.com/apitoken`. [VERIFIED: CONTEXT.md specifics section]

### Pattern 4: Runbook Format (from add-credential.md)

**What:** The existing runbooks follow a specific markdown structure. The new runbook must match.

**Structure extracted from `add-credential.md`:**
1. Title line (`# Runbook: <action>`)
2. One-paragraph description of scope and audience
3. Callout block (blockquote) for "when NOT to use this runbook" (if applicable)
4. `## Prerequisites` section — bulleted list (OpenBao reachable, token in hand)
5. `## Steps` section with numbered `### N. Step Name` subsections
6. Each step: explanation sentence, then fenced code block(s) with comments
7. Inline `>` blockquote notes for important caveats (e.g., immutability warning)
8. `## Troubleshooting` section with a two-column markdown table: `| Symptom | Likely cause |`

**Immutability warning placement:** Must appear as a blockquote immediately after the `openssl rand` command, before the `bao kv put` step. [VERIFIED: D-05 in CONTEXT.md, CLAUDE.md constraint]

### Anti-Patterns to Avoid

- **Modifying cluster-secret-store.yaml:** The ClusterSecretStore does not need changes — ESO's auth role and store path are already correct. Only the policy bound to that role changes.
- **Writing policy inline (heredoc) instead of from file:** D-01 requires the file be the durable record. Do not instruct `bao policy write eso-policy - <<EOF`; always reference the committed file.
- **Separate `bao kv put` calls for each field:** Two sequential puts risk partial state if the second fails. Use one command with both key=value pairs.
- **Using `bao kv patch` for the initial write:** `kv patch` is for updating existing secrets without clobbering keys. For a net-new path (`secret/aiostreams/production` does not exist), use `kv put`. [VERIFIED: add-credential.md note "If the path doesn't exist yet, use kv put for the first write"]

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Cryptographically random key generation | Custom PRNG or UUID | `openssl rand -hex 32` | `openssl` uses OS entropy; output is exactly 64 hex chars = 32 bytes; already established in homelab conventions |
| Policy file verification | Manual diff or custom check script | `bao policy show eso-policy` | OpenBao echoes back the stored policy; direct comparison to the HCL file is sufficient |
| Secret verification | Application smoke test | `bao kv get secret/aiostreams/production` | Directly queries the stored values before any K8s dependency exists |

**Key insight:** Every operation in Phase 1 has a direct inverse verification command built into the `bao` CLI. There is no need for any custom tooling or scripts.

---

## Runtime State Inventory

> Included because this phase writes live OpenBao state that persists across sessions.

| Category | Items Found | Action Required |
|----------|-------------|------------------|
| Stored data | `secret/aiostreams/production` does not yet exist (new path) | `bao kv put` creates it; no migration needed |
| Stored data | `secret/homelab/ci` exists and must not be disturbed | `bao kv put` on a different path; zero risk of collision |
| Live service config | `eso-policy` in OpenBao contains only `secret/data/homelab/ci` [VERIFIED: openbao-auth-config.yml] | `bao policy write` overwrites the full policy; the new HCL must include both paths |
| Live service config | `eso-reader` Kubernetes auth role already bound to `eso-policy` [VERIFIED: openbao-auth-config.yml, cluster-secret-store.yaml] | No role change needed — policy name stays `eso-policy` |
| OS-registered state | None — no cron, systemd, or Task Scheduler entries involved | None |
| Secrets/env vars | `VAULT_ADDR` / `-address` flag required for all `bao` commands | Operator must have OpenBao token in hand; token not stored anywhere in Phase 1 |
| Build artifacts | None | None |

**Nothing found in category (OS-registered state, build artifacts):** Verified — Phase 1 touches only OpenBao state and git files.

---

## Common Pitfalls

### Pitfall 1: Policy Overwrite Drops Existing Paths

**What goes wrong:** `bao policy write eso-policy <file>` is a full replacement, not an append. If `eso-policy.hcl` only contains the `aiostreams/*` path and omits `secret/data/homelab/ci`, the CI pipeline immediately loses read access to its credentials.

**Why it happens:** Operators write a minimal policy file focused on the new path, forgetting the existing scope.

**How to avoid:** The committed `eso-policy.hcl` MUST include both paths. Verify after applying with `bao policy show eso-policy` and confirm both `homelab/ci` and `aiostreams/*` are present.

**Warning signs:** After policy update, CI pipelines return `403` on `secret/data/homelab/ci`.

### Pitfall 2: SECRET_KEY Changed After First Use

**What goes wrong:** Operator re-runs `openssl rand -hex 32` and calls `bao kv put` again, rotating the key. All user sessions and saved configs in AIOStreams immediately become invalid.

**Why it happens:** `bao kv put` on an existing path overwrites all fields. Operators may not realize the immutability constraint.

**How to avoid:** The runbook must include a prominent warning (blockquote) immediately after the `openssl rand` command. After initial provisioning, use `bao kv patch` if any other field needs updating, never `bao kv put` on this path again. The runbook should note "generate once, never rotate."

**Warning signs:** AIOStreams users report their configuration is reset or authentication fails.

### Pitfall 3: Missing `-address` Flag or `VAULT_ADDR` Not Set

**What goes wrong:** `bao kv put secret/aiostreams/production ...` fails with a connection error because the CLI defaults to `http://127.0.0.1:8200`.

**Why it happens:** The operator's local machine is not OpenBao; the instance is at `192.168.1.210`.

**How to avoid:** Every `bao` command in the runbook must include `-address=http://192.168.1.210:8200` OR the runbook's Prerequisites section must instruct the operator to `export VAULT_ADDR=http://192.168.1.210:8200` before proceeding. Follow the pattern in `add-credential.md` which includes `-address=` on every command.

**Warning signs:** `Error making API request: dial tcp 127.0.0.1:8200: connect: connection refused`

### Pitfall 4: OpenBao Sealed

**What goes wrong:** All `bao` commands return HTTP 503 because OpenBao restarted (pod restart, node reboot) and is in sealed state.

**Why it happens:** OpenBao uses manual unseal (per ADR-005). No auto-unseal configured.

**How to avoid:** Prerequisites section must include "OpenBao is unsealed — verify with `bao status -address=http://192.168.1.210:8200`". Troubleshooting table must cover the sealed state symptom.

**Warning signs:** `Error making API request: ... 503 Service Unavailable` or `bao status` shows `Sealed: true`.

### Pitfall 5: Cross-Repo Commit Sequence

**What goes wrong:** Planner treats Phase 1 as a single-repo operation and generates a plan that commits everything to `C:\repos\infra`. The runbook file actually belongs in `C:\repos\homelab-knowledge` which is a separate git repo.

**Why it happens:** The two repos live side by side at `C:\repos\` and are easy to confuse.

**How to avoid:** Plan must explicitly distinguish two git operations:
- Commit 1: `C:\repos\infra` — `kubernetes/external-secrets/eso-policy.hcl`
- Commit 2: `C:\repos\homelab-knowledge` — `runbooks/provision-aiostreams-secrets.md`

---

## Code Examples

Verified patterns from authoritative sources:

### Complete eso-policy.hcl Content

```hcl
# kubernetes/external-secrets/eso-policy.hcl
# Source: existing path verified from ansible/playbooks/openbao-auth-config.yml
# New path per INFRA-01

path "secret/data/homelab/ci" {
  capabilities = ["read"]
}

path "secret/data/aiostreams/*" {
  capabilities = ["read", "list"]
}
```

### Apply Policy

```bash
# Source: pattern from add-credential.md; run from C:\repos\infra root
bao policy write -address=http://192.168.1.210:8200 eso-policy kubernetes/external-secrets/eso-policy.hcl
bao policy show -address=http://192.168.1.210:8200 eso-policy
```

### Generate and Store Secrets

```bash
# Source: pattern from provision-app-secrets.md

# Generate SECRET_KEY (immutable — see immutability warning)
SECRET_KEY=$(openssl rand -hex 32)

# Write both fields atomically (net-new path — use kv put, not kv patch)
bao kv put -address=http://192.168.1.210:8200 secret/aiostreams/production \
  SECRET_KEY="$SECRET_KEY" \
  FORCED_SERVICE_CREDENTIALS="realdebrid.apiKey=<YOUR_RD_API_KEY>"

# Verify
bao kv get -address=http://192.168.1.210:8200 secret/aiostreams/production
```

### Runbook Troubleshooting Table (format to replicate)

```markdown
## Troubleshooting

| Symptom | Likely cause |
|---------|-------------|
| `503 Service Unavailable` from bao | OpenBao pod is sealed — run `bao operator unseal` |
| `403 permission denied` on policy write | Token lacks `sys/policy/write` — use root token |
| `bao kv get` returns empty or missing fields | Secret path typo — verify `secret/aiostreams/production` |
| ESO sync shows `permission denied` (Phase 2) | Policy not applied, or applied without aiostreams/* path |
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Vault CLI (`vault kv put`) | `bao` CLI (drop-in replacement) | OpenBao fork of HashiCorp Vault | Identical syntax; `bao` is the correct binary name for this homelab |
| `kv put` for updates | `kv patch` for non-destructive updates | KV v2 feature | Use `kv put` for first write (creates path); `kv patch` for subsequent field additions |

**Deprecated/outdated:**
- `vault` CLI: Not wrong (API-compatible per ADR-005), but `bao` is the canonical binary name for OpenBao installations. Use `bao` in all runbook commands for consistency.

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `openssl` is available on the operator's machine | Standard Stack | Low — openssl is universally available on macOS/Linux; runbook should note as prerequisite |
| A2 | `list` capability needed alongside `read` for `secret/data/aiostreams/*` | Pattern 2 | Low — ESO only needs `read` to fetch specific paths; `list` is optional. Either works; `read` alone is sufficient and matches the existing `homelab/ci` path. Planner may use `["read"]` only to match existing convention |

---

## Open Questions

1. **Does the live eso-policy in OpenBao exactly match the Ansible playbook content?**
   - What we know: `openbao-auth-config.yml` provisioned the policy with only `secret/data/homelab/ci`
   - What's unclear: Whether any out-of-band changes were made to the live policy after the Ansible run
   - Recommendation: Runbook Step 0 (or planner pre-check) should include `bao policy show eso-policy` to confirm current state before overwriting. This is a safe read-only verification.

2. **Should `secret/data/aiostreams/*` use `["read"]` or `["read", "list"]`?**
   - What we know: ESO fetches a specific KV path (`secret/aiostreams/production`) — it does not need to enumerate secrets. The `homelab/ci` path uses only `["read"]`.
   - What's unclear: Whether any future ESO usage pattern would need `list`
   - Recommendation: Use `["read"]` to match existing convention and minimize permissions. Planner's discretion (per CONTEXT.md).

---

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| `bao` CLI | All OpenBao operations | [ASSUMED] present on operator machine | Unknown | Use `vault` CLI (API-compatible per ADR-005) |
| `openssl` | SECRET_KEY generation | [ASSUMED] present (standard POSIX tool) | Unknown | `python3 -c "import secrets; print(secrets.token_hex(32))"` |
| OpenBao instance | Secret storage | ✓ (established) | http://192.168.1.210:8200 | None — must be unsealed before Phase 1 runs |
| Git (infra repo) | Commit eso-policy.hcl | ✓ (repo exists at C:\repos\infra) | — | — |
| Git (homelab-knowledge repo) | Commit runbook | ✓ (repo exists at C:\repos\homelab-knowledge) | — | — |

**Missing dependencies with no fallback:**
- OpenBao must be unsealed before bao CLI commands can succeed. If sealed, operator must run `bao operator unseal` first.

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | Manual CLI verification (no automated test framework for OpenBao operations) |
| Config file | none |
| Quick run command | `bao policy show -address=http://192.168.1.210:8200 eso-policy` |
| Full suite command | `bao policy show eso-policy && bao kv get -address=http://192.168.1.210:8200 secret/aiostreams/production` |

### Phase Requirements to Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| INFRA-01 | `eso-policy` includes `secret/data/aiostreams/*` | smoke | `bao policy show -address=http://192.168.1.210:8200 eso-policy \| grep aiostreams` | N/A (CLI op) |
| INFRA-02 | `SECRET_KEY` is 64-char hex at `secret/aiostreams/production` | smoke | `bao kv get -address=http://192.168.1.210:8200 secret/aiostreams/production` | N/A (CLI op) |
| INFRA-03 | `FORCED_SERVICE_CREDENTIALS` field present with correct format | smoke | `bao kv get -address=http://192.168.1.210:8200 secret/aiostreams/production` | N/A (CLI op) |
| INFRA-04 | Runbook file exists at correct path | manual | `ls C:\repos\homelab-knowledge\runbooks\provision-aiostreams-secrets.md` | ❌ Wave 0 |

### Sampling Rate

- **Per task commit:** Run the relevant `bao` verification command for that task
- **Per wave merge:** `bao policy show eso-policy && bao kv get secret/aiostreams/production`
- **Phase gate:** Both commands return expected output with no error before Phase 2 begins

### Wave 0 Gaps

- [ ] `C:\repos\homelab-knowledge\runbooks\provision-aiostreams-secrets.md` — covers INFRA-04 (created in Wave 1 of this phase)

---

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | OpenBao auth is pre-configured (Kubernetes auth + eso-reader role) |
| V3 Session Management | no | ESO uses short-lived K8s tokens; no session management in Phase 1 |
| V4 Access Control | yes | Policy scoping: `read` only, specific path glob, no write/delete |
| V5 Input Validation | no | No user input in Phase 1; values are operator-supplied at CLI |
| V6 Cryptography | yes | `openssl rand -hex 32` for SECRET_KEY; do not use weaker generators |

### Known Threat Patterns

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Overly broad policy scope (`secret/*` instead of `secret/data/aiostreams/*`) | Elevation of Privilege | Glob is scoped to one app path; verify with `bao policy show` after apply |
| SECRET_KEY in shell history | Information Disclosure | Use variable capture (`SECRET_KEY=$(openssl rand -hex 32)`); avoid echoing raw value to terminal |
| Committing SECRET_KEY or RD API key to git | Information Disclosure | Phase 1 writes secrets to OpenBao only; the HCL file contains no credential values |

---

## Sources

### Primary (HIGH confidence)
- `C:\repos\infra\ansible\playbooks\openbao-auth-config.yml` — authoritative source of current eso-policy content (lines 83-86) and eso-reader role binding (lines 89-104)
- `C:\repos\infra\kubernetes\external-secrets\cluster-secret-store.yaml` — confirms: KV v2, Kubernetes auth, role `eso-reader`, server `http://192.168.1.210:8200`
- `C:\repos\homelab-knowledge\runbooks\add-credential.md` — runbook format template (markdown structure, troubleshooting table format, `bao kv patch` vs `put` distinction)
- `C:\repos\homelab-knowledge\runbooks\provision-app-secrets.md` — `bao kv put` syntax for new paths, path naming convention `secret/<app>/<env>`
- `C:\repos\homelab-knowledge\adr\ADR-005-openbao-secrets-manager.md` — KV v2 at `secret/homelab/ci`, token auth for operator, manual unseal behavior
- `C:\repos\homelab-knowledge\adr\ADR-011-external-secrets-operator.md` — ESO uses Kubernetes auth (not AppRole), `eso-reader` role, `eso-policy` name

### Secondary (MEDIUM confidence)
- `C:\repos\infra\.planning\phases\01-secrets-and-prerequisites\01-CONTEXT.md` — locked decisions, runbook structure requirements, field naming conventions, Real-Debrid URL

### Tertiary (LOW confidence — none in this research)
- All claims verified from source files in the repos.

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all tools verified from existing runbooks and Ansible playbooks
- Architecture: HIGH — ESO/OpenBao integration verified from cluster-secret-store.yaml and ADR-011
- Current eso-policy content: HIGH — read directly from openbao-auth-config.yml (the provisioning source)
- Pitfalls: HIGH — derived from KV v2 behavior documented in existing runbooks and ADR-005

**Research date:** 2026-05-12
**Valid until:** 2026-06-12 (stable infrastructure; OpenBao API is stable)
