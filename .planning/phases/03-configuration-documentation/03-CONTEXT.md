# Phase 3: Configuration & Documentation - Context

**Gathered:** 2026-05-13
**Status:** Ready for planning

<domain>
## Phase Boundary

Deliver the final documentation layer that makes AIOStreams usable and maintainable: (1) a step-by-step UI setup runbook in `homelab-knowledge/runbooks/setup-aiostreams.md` covering Torrentio source, RD credential verification, and filter activation; (2) a filter validation procedure at `.planning/runbooks/validate-filter.md` (Stremio UI only, one-time confirmation); and (3) ADR-017 in `homelab-knowledge/adr/` recording the deployment decision. This phase ends when the filter is validated in Stremio and the ADR is committed.

</domain>

<decisions>
## Implementation Decisions

### Validation procedure
- **D-01:** Filter validation procedure lives at `.planning/runbooks/validate-filter.md` — a project artifact, not a reusable operational runbook. Matches ROADMAP.md success criteria; treats filter validation as a one-time confirmation, not an ongoing procedure.
- **D-02:** Validation method: Stremio UI only. Operator searches for a known WEB-DL/YTS/AMZN-tagged release in Stremio and confirms filtered streams do not appear. No curl/API testing required.

### UI setup runbook (CONF-01)
- **D-03:** UI setup runbook lives at `homelab-knowledge/runbooks/setup-aiostreams.md` — permanent operational doc, consistent with D-04 from Phase 1. Future operators find secrets provisioning and UI setup in the same place.
- **D-04:** Runbook must cross-link `provision-aiostreams-secrets.md` as a prerequisite in the Prerequisites section. Pod must be running and secrets synced before UI setup begins.
- **D-05:** Runbook style: step-by-step with specific AIOStreams UI paths (menu names, tabs, field names). Version-pinned to v2.29.5 — note the version at the top so operators know to verify steps if the version changes.
- **D-06:** Even though `FORCED_SERVICE_CREDENTIALS` pre-seeds RD credentials via env var, the runbook instructs the operator to open the AIOStreams UI and verify Real-Debrid shows as connected. Defense-in-depth: catches ESO sync failures and ensures the pod actually picked up the secret.

### ADR
- **D-07:** ADR-017 covers the deployment decision only (not implementation details like SQLite, ConfigMap structure, or network topology). Sections: Context (RD May 2026 blocks, problem description), Decision (self-hosted AIOStreams on k3s), Alternatives Considered (Comet, ElfHosted, switch debrid providers), Consequences (regex maintenance cadence, SECRET_KEY immutability constraint).
- **D-08:** Three alternatives to address explicitly: Comet (alternative filtering addon with RD support), ElfHosted hosted AIOStreams (SaaS vs. self-hosted trade-off), switching debrid providers (TorBox, Usenet). These are the three the project evaluated.
- **D-09:** ADR number is **ADR-017**. CLAUDE.md says "next: ADR-016" but that's stale — ADR-016 was committed to homelab-knowledge for the infra-on-proxmox decision. Planner must use ADR-017 and filename `ADR-017-aiostreams-stremio-filtering.md`.

### Claude's Discretion
- Exact Torrentio manifest URL to document in the setup runbook. Researcher should verify the current URL against AIOStreams documentation or Torrentio's published addon URL.
- Troubleshooting table contents for setup-aiostreams.md (follow `add-credential.md` format: Symptom / Likely cause columns).
- How to describe AIOStreams filter activation in the UI — whether it's a toggle, a setting, or configured via the web interface's filter management screen.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### ADR format
- `../homelab-knowledge/adr/ADR-016-infra-on-proxmox-apps-on-k3s.md` — latest ADR; use this as the format template (Status, Date, Context, Decision, Alternatives Considered, Consequences)
- `../homelab-knowledge/adr/ADR-011-external-secrets-operator.md` — prior ADR for additional format reference

### Runbook format
- `../homelab-knowledge/runbooks/add-credential.md` — canonical runbook format (Prerequisites, numbered Steps, Troubleshooting table)
- `../homelab-knowledge/runbooks/provision-aiostreams-secrets.md` — existing Phase 1 runbook; setup-aiostreams.md cross-links this as a prerequisite

### Phase context (decisions that carry forward)
- `.planning/phases/01-secrets-and-prerequisites/01-CONTEXT.md` — D-04: operational runbooks belong in homelab-knowledge/runbooks/
- `.planning/phases/02-kubernetes-manifests/02-CONTEXT.md` — D-02/D-03: AIOStreams IP is 192.168.1.205, BASE_URL; D-04/D-05: regex pattern and ConfigMap decisions; reference for what the running deployment looks like

### Requirements
- `.planning/REQUIREMENTS.md` — CONF-01, CONF-02, DOC-01 acceptance criteria

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- No code to write — pure documentation phase.

### Established Patterns
- **ADR numbering:** ADR-017 is next. File must be named `ADR-017-aiostreams-stremio-filtering.md` in `homelab-knowledge/adr/`.
- **Runbook format:** Prerequisites → numbered Steps → Troubleshooting table. See `add-credential.md`.
- **homelab-knowledge is a separate repo** at `../homelab-knowledge/` relative to the infra repo. Changes require a separate commit and push to `ssh://git@192.168.1.50:2222/tbtaylor100/homelab-knowledge.git`.

### Integration Points
- AIOStreams UI: `http://192.168.1.205:3000` (MetalLB LoadBalancer)
- WHITELISTED_REGEX_PATTERNS already pre-seeded via ConfigMap: `["/(WEB-DL|AMZN|DSNP|YTS|RARBG|EZTV)/i"]`
- REGEX_FILTER_ACCESS=all: filter is globally available without per-user trust configuration
- FORCED_SERVICE_CREDENTIALS: pre-seeded via ExternalSecret, but UI verification is required per D-06

</code_context>

<specifics>
## Specific Ideas

- The setup runbook should note that `WHITELISTED_REGEX_PATTERNS` and `REGEX_FILTER_ACCESS=all` are already pre-configured — the operator only needs to activate/enable the filter in the UI, not re-enter the regex.
- ADR-017 should reference the May 2026 RD block event as the triggering incident with a concrete date, making it easier to understand the "why" when read years later.
- The validate-filter.md should name specific release tags to search for (e.g., "search for a 'WEB-DL' tagged release of any popular TV show") rather than relying on the operator to know which tags are blocked.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 3-configuration-documentation*
*Context gathered: 2026-05-13*
