# Phase 3: Configuration & Documentation - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-05-13
**Phase:** 03-configuration-documentation
**Areas discussed:** Validation procedure placement, CONF-01 + CONF-02 doc structure, UI runbook depth, ADR scope

---

## Validation Procedure Placement

| Option | Description | Selected |
|--------|-------------|----------|
| `.planning/runbooks/validate-filter.md` | Project artifact — disposable once filter confirmed working. Matches ROADMAP.md spec. Not a reusable operational doc. | ✓ |
| `homelab-knowledge/runbooks/validate-aiostreams-filter.md` | Durable operational doc — survives project teardown, useful if filter needs re-validation after regex update. Consistent with D-04. | |
| Inline in the setup runbook (CONF-01) | A 'Validation' section at the end of the AIOStreams setup runbook. One document start-to-finish. | |

**User's choice:** `.planning/runbooks/validate-filter.md`
**Notes:** Treated as a one-time project-scoped test, not a recurring operational procedure.

**Validation method:**

| Option | Description | Selected |
|--------|-------------|----------|
| Stremio UI only | Search for known WEB-DL/YTS/AMZN release in Stremio and confirm filtered streams don't appear. | ✓ |
| curl AIOStreams API + Stremio UI | Also query AIOStreams directly to inspect JSON response. More thorough, more technical. | |
| AIOStreams UI filter preview | Use AIOStreams built-in filter preview to confirm regex before Stremio test. | |

**User's choice:** Stremio UI only
**Notes:** User-observable validation, no tooling or API knowledge required.

---

## CONF-01 + CONF-02 Doc Structure

**UI setup runbook location:**

| Option | Description | Selected |
|--------|-------------|----------|
| `homelab-knowledge/runbooks/setup-aiostreams.md` | Permanent operational doc alongside provision runbook. Consistent with D-04 from Phase 1. | ✓ |
| `.planning/runbooks/setup-aiostreams.md` | Project artifact only. One-time configuration, doesn't need to survive the project planning folder. | |

**User's choice:** `homelab-knowledge/runbooks/setup-aiostreams.md`
**Notes:** Keeps all AIOStreams operational docs in one place for future operators.

**Cross-linking:**

| Option | Description | Selected |
|--------|-------------|----------|
| Yes — cross-link as prerequisite | Add Prerequisites note pointing to provision-aiostreams-secrets.md. Operators get clear dependency chain. | ✓ |
| No — standalone doc | Assume prerequisites are obvious. Keep runbook self-contained. | |

**User's choice:** Yes — cross-link as prerequisite
**Notes:** Prerequisites section should reference both provision-aiostreams-secrets.md (secrets) and the running pod state (Phase 2).

---

## UI Runbook Depth

**Step granularity:**

| Option | Description | Selected |
|--------|-------------|----------|
| Step-by-step with UI paths | Specific menu names, tabs, fields — e.g., 'Navigate to Settings > Addons, paste manifest URL, click Install.' Easy to follow, brittle if UI changes. | ✓ |
| High-level checklist of config goals | WHAT to configure without step-by-step UI paths. Version-agnostic but requires operator to find settings. | |
| You decide | Let executor pick appropriate level based on AIOStreams docs and UI complexity. | |

**User's choice:** Step-by-step with UI paths
**Notes:** Accepted the version-brittleness trade-off in favor of ease of use during initial setup.

**RD credential verification:**

| Option | Description | Selected |
|--------|-------------|----------|
| Verify in UI anyway | Open AIOStreams UI and confirm RD shows as connected even though env var pre-seeds it. Defense-in-depth. | ✓ |
| Skip UI credential step | Trust the env var injection. Only cover Torrentio source and filter activation. | |

**User's choice:** Verify in UI anyway
**Notes:** Catches ESO sync failures that would otherwise only surface during Stremio use.

---

## ADR Scope

**Breadth:**

| Option | Description | Selected |
|--------|-------------|----------|
| Deployment decision only | Context, Decision, Alternatives (Comet/ElfHosted/switch providers), Consequences. Clean and focused. | ✓ |
| Broad — all AIOStreams-specific choices | Also cover SQLite vs. Postgres, intranet-only, ConfigMap for regex, quarterly review cadence. | |

**User's choice:** Deployment decision only
**Notes:** Matches the scope and style of ADR-016 (infra-on-proxmox) and ADR-011 (ESO).

**Alternatives to address:**

| Option | Description | Selected |
|--------|-------------|----------|
| Comet + ElfHosted + switch providers | All three realistic alternatives the project evaluated. | ✓ |
| Only ElfHosted vs. self-hosted | Core trade-off only — Comet and provider switching are secondary. | |
| You decide | Executor surfaces alternatives that fit ADR-016 format. | |

**User's choice:** Comet + ElfHosted + switch providers
**Notes:** Comet (alternative addon), ElfHosted (SaaS option), TorBox/Usenet (provider switching).

---

## Claude's Discretion

- Torrentio manifest URL to document in setup runbook (researcher to verify current URL)
- Troubleshooting table contents for setup-aiostreams.md
- How to describe AIOStreams filter activation in the UI (toggle, setting, or filter management screen)

## Deferred Ideas

None — discussion stayed within phase scope.
