# Phase 1: Secrets & Prerequisites - Context

**Gathered:** 2026-05-12
**Status:** Ready for planning

<domain>
## Phase Boundary

Extend the OpenBao `eso-policy` to cover `secret/data/aiostreams/*`, generate and store AIOStreams credentials (`SECRET_KEY`, `FORCED_SERVICE_CREDENTIALS`) at `secret/aiostreams/production`, and write an operational provisioning runbook in `homelab-knowledge`. This phase ends when ESO can sync those secrets without a permission error — no Kubernetes manifests yet.

</domain>

<decisions>
## Implementation Decisions

### Policy HCL storage
- **D-01:** The updated `eso-policy` HCL is committed to the infra repo at `kubernetes/external-secrets/eso-policy.hcl` alongside `cluster-secret-store.yaml`. This is the file that `bao policy write` reads. The policy is applied manually once; the file is the durable record.
- **D-02:** The runbook documents the `bao policy write` command as a thin one-liner referencing the file path, not a full walkthrough. Policy changes are infrequent and the file speaks for itself.

### OpenBao field naming
- **D-03:** Field names in `secret/aiostreams/production` match the env var names the workload expects: `SECRET_KEY` and `FORCED_SERVICE_CREDENTIALS`. No remapping in the ExternalSecret is needed. This is not a homelab-wide standard — the path convention (`secret/<app>/<env>`) is already the standard; field names are owned by the service.

### Runbook
- **D-04:** The provisioning runbook lives at `homelab-knowledge/runbooks/provision-aiostreams-secrets.md` — not `.planning/runbooks/`. `.planning/` is project scaffolding and can be overwritten; operational runbooks belong in `homelab-knowledge` alongside ADRs.
- **D-05:** Runbook structure follows the existing format in `homelab-knowledge/runbooks/`:
  - Prerequisites (OpenBao reachable, root/admin token in hand)
  - Step 1: Apply eso-policy (one-liner: `bao policy write eso-policy kubernetes/external-secrets/eso-policy.hcl`) + verify with `bao policy show`
  - Step 2: Generate `SECRET_KEY` via `openssl rand -hex 32` — **prominent immutability warning**: changing SECRET_KEY after first use invalidates all saved user configs; generate once, never rotate
  - Step 3: Create secret at `secret/aiostreams/production` with both fields in one `bao kv put` — include Real-Debrid API key source URL (`https://real-debrid.com/apitoken`)
  - Step 4: Verify with `bao kv get secret/aiostreams/production`
  - Troubleshooting table (matching `add-credential.md` format): sealed OpenBao, permission denied on policy write, ESO sync failure

### Claude's Discretion
- Exact HCL content of `eso-policy.hcl` (must include both the existing `secret/data/homelab/ci` path and the new `secret/data/aiostreams/*` path — planner should verify against the current policy before writing)
- Whether to use `bao kv put` or `bao kv patch` for initial secret creation (either is fine; `put` is simpler for a net-new path)

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### ESO + OpenBao integration
- `kubernetes/external-secrets/cluster-secret-store.yaml` — ESO ClusterSecretStore config; Kubernetes auth using role `eso-reader`; confirms the auth method is Kubernetes (not AppRole), and the existing policy name to extend
- `homelab-knowledge/adr/ADR-011-external-secrets-operator.md` — decision to use ESO; describes the ClusterSecretStore/ExternalSecret pattern
- `homelab-knowledge/adr/ADR-005-openbao-secrets-manager.md` — OpenBao setup and KV v2 path conventions

### Existing runbook patterns
- `homelab-knowledge/runbooks/provision-app-secrets.md` — general app secrets pattern (note: this uses AppRole auth for CI workflows, NOT what Phase 1 needs; ESO uses Kubernetes auth)
- `homelab-knowledge/runbooks/add-credential.md` — shows the format for extending a policy and adding a credential; matches the style Phase 1's runbook should follow

### ArgoCD pattern (for awareness — Phase 2 uses this)
- `argocd/apps/mcp-servers.yaml` — canonical ArgoCD Application CR with `CreateNamespace=true` and automated prune/self-heal

</canonical_refs>

<code_context>
## Existing Code Insights

### Established Patterns
- **ESO auth is Kubernetes, not AppRole:** `cluster-secret-store.yaml` uses `auth.kubernetes.role: eso-reader`. Phase 1 extends the policy bound to that role — no new AppRole or role_id/secret_id involved.
- **OpenBao address:** `http://192.168.1.210:8200` — all `bao` CLI commands need `-address=http://192.168.1.210:8200` or `VAULT_ADDR` set.
- **KV v2:** ClusterSecretStore sets `version: v2`. Secret paths are `secret/data/...` in the API but `secret/...` in the `bao kv` CLI.
- **Policy name:** The role `eso-reader` is bound to a policy named `eso-policy` (per STATE.md). The file to write/update is `eso-policy`, not a new name.

### Integration Points
- `kubernetes/external-secrets/eso-policy.hcl` (new file) — applied via `bao policy write eso-policy <file>` once Phase 1 is complete
- `homelab-knowledge/runbooks/provision-aiostreams-secrets.md` (new file) — written to a separate repo; planner must account for this being a cross-repo change

</code_context>

<specifics>
## Specific Ideas

- Real-Debrid API key URL: `https://real-debrid.com/apitoken` — include this in the runbook so the operator knows where to retrieve it
- `SECRET_KEY` immutability is a hard constraint documented in AIOStreams: once the app starts and a user saves config, the key cannot change without invalidating their session. The runbook warning must be unmissable.
- The `FORCED_SERVICE_CREDENTIALS` value format is `realdebrid.apiKey=<key>` — this is the full value stored in OpenBao, not just the API key itself.

</specifics>

<deferred>
## Deferred Ideas

- ADR-016 for OpenBao field naming convention: discussed and resolved as a non-issue — the path convention (`secret/<app>/<env>`) is already the standard; field names are service-owned. No separate ADR needed.

</deferred>

---

*Phase: 1-Secrets & Prerequisites*
*Context gathered: 2026-05-12*
