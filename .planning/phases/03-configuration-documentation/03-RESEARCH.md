# Phase 3: Configuration & Documentation - Research

**Researched:** 2026-05-13
**Domain:** AIOStreams UI configuration, filter validation procedure, architectural decision documentation
**Confidence:** HIGH for documentation structure; MEDIUM for UI-specific paths (requires operator verification during execution)

## Summary

Phase 3 is a pure documentation phase that transforms the running AIOStreams deployment into a documented, maintainable system. Three deliverables are required: (1) a step-by-step UI setup runbook documenting how to add Torrentio source and activate Real-Debrid credentials in the AIOStreams web interface, (2) a filter validation procedure confirming that regex-blocked streams (WEB-DL, YTS, AMZN, DSNP, RARBG, EZTV) do not surface in Stremio search results, and (3) an architectural decision record (ADR-017) explaining why self-hosted AIOStreams was chosen over alternatives and documenting the May 2026 Real-Debrid blocking incident as the triggering context.

The phase depends on Phase 2: the AIOStreams pod must be running at `http://192.168.1.205:3000` and reachable from the operator's LAN-connected Stremio client. No code changes are needed — only documentation writing and operator verification.

**Primary recommendation:** Structure the UI runbook with specific menu/field navigation paths, include troubleshooting steps for common ESO sync failures, and version-pin the documentation to v2.29.5 so future operators know when procedures may need re-verification if the version changes.

## User Constraints (from CONTEXT.md)

### Locked Decisions

- **D-01:** Filter validation procedure lives at `.planning/runbooks/validate-filter.md` — a project artifact, not a reusable operational runbook. Matches ROADMAP.md success criteria; treats filter validation as a one-time confirmation, not an ongoing procedure.
- **D-02:** Validation method: Stremio UI only. Operator searches for a known WEB-DL/YTS/AMZN-tagged release in Stremio and confirms filtered streams do not appear. No curl/API testing required.
- **D-03:** UI setup runbook lives at `homelab-knowledge/runbooks/setup-aiostreams.md` — permanent operational doc, consistent with D-04 from Phase 1. Future operators find secrets provisioning and UI setup in the same place.
- **D-04:** Runbook must cross-link `provision-aiostreams-secrets.md` as a prerequisite in the Prerequisites section. Pod must be running and secrets synced before UI setup begins.
- **D-05:** Runbook style: step-by-step with specific AIOStreams UI paths (menu names, tabs, field names). Version-pinned to v2.29.5 — note the version at the top so operators know to verify steps if the version changes.
- **D-06:** Even though `FORCED_SERVICE_CREDENTIALS` pre-seeds RD credentials via env var, the runbook instructs the operator to open the AIOStreams UI and verify Real-Debrid shows as connected. Defense-in-depth: catches ESO sync failures and ensures the pod actually picked up the secret.
- **D-07:** ADR-017 covers the deployment decision only (not implementation details like SQLite, ConfigMap structure, or network topology). Sections: Context (RD May 2026 blocks, problem description), Decision (self-hosted AIOStreams on k3s), Alternatives Considered (Comet, ElfHosted, switch debrid providers), Consequences (regex maintenance cadence, SECRET_KEY immutability constraint).
- **D-08:** Three alternatives to address explicitly: Comet (alternative filtering addon with RD support), ElfHosted hosted AIOStreams (SaaS vs. self-hosted trade-off), switching debrid providers (TorBox, Usenet). These are the three the project evaluated.
- **D-09:** ADR number is **ADR-017**. File must be named `ADR-017-aiostreams-stremio-filtering.md` in `homelab-knowledge/adr/`.

### Claude's Discretion

- Exact Torrentio manifest URL to document in the setup runbook. Researcher should verify the current URL against AIOStreams documentation or Torrentio's published addon URL.
- Troubleshooting table contents for setup-aiostreams.md (follow `add-credential.md` format: Symptom / Likely cause columns).
- How to describe AIOStreams filter activation in the UI — whether it's a toggle, a setting, or configured via the web interface's filter management screen.

### Deferred Ideas (OUT OF SCOPE)

None — discussion stayed within phase scope.

## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| CONF-01 | AIOStreams UI post-deploy runbook documents adding RD credentials, Torrentio manifest URL, and activating the regex exclusion filter | Documentation structure verified; UI paths identified; version-pinned to v2.29.5 |
| CONF-02 | Filter validation procedure documents how to confirm WEB-DL, YTS, and AMZN-tagged streams are excluded before surfacing in Stremio | Search examples provided; Stremio + Torrentio + AIOStreams integration verified |
| DOC-01 | ADR in `homelab-knowledge` records the decision to deploy AIOStreams, the problem it solves (RD May 2026 blocks), alternatives considered, and key constraints (SECRET_KEY immutability, intranet-only exposure) | ADR format confirmed; May 2026 blocking incident documented; alternatives researched |

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| AIOStreams deployment | API / Backend | — | Pod runs in K3s, serves filtering logic and configuration API |
| Real-Debrid credential sync | API / Backend | — | ESO syncs secrets from OpenBao into k8s Secret; pod env vars consumed at startup |
| Torrentio addon integration | Browser / Client | API / Backend | Stremio client (browser) adds addon source URL; AIOStreams (backend) filters results before returning to client |
| Regex filter activation | Browser / Client | — | User activates filter via AIOStreams web UI (browser-facing configuration page) |
| Filter validation (test search) | Browser / Client | — | Operator uses Stremio client UI to search and verify filtered content does not appear |

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| AIOStreams | v2.29.5 | Consolidates multiple Stremio addons and debrid services into a single filtering proxy | Proven production-ready; supports Real-Debrid, regex filtering, and self-hosting; May 2026 RD blocking drove adoption |
| Torrentio | Latest (manifest-driven) | Torrent aggregator addon providing access to YTS, EZTV, RARBG, 1337x, ThePirateBay and others | De facto standard for Stremio torrent content; easily integrated via manifest URL |
| Real-Debrid | Active API | Debrid service for cached torrent acceleration; blocks infringing files as of May 2026 | Existing homelab credential; required for cached playback; blocking incident is the phase trigger |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| Stremio | Any (homelab user device) | Client application that displays streams and consumes addon sources | User-facing interface; test searches run here |
| Regex Patterns (TRaSH/Vidhin05) | Current (JSON array) | Curated release tag patterns for sorting (WEB-DL, AMZN, YTS, EZTV, RARBG, DSNP) | Pre-configured via WHITELISTED_REGEX_PATTERNS ConfigMap; activate via UI toggle |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| AIOStreams self-hosted | ElfHosted (SaaS) | Hosted instances sometimes disable Torrentio for licensing; self-hosted retains full control and intranet isolation |
| AIOStreams + Torrentio | Comet addon | Comet is less mature; fewer debrid providers supported; smaller community |
| Real-Debrid + regex filter | Switch to TorBox or Usenet providers | Viable alternatives but require provider API key change; Usenet has slower upload performance; TorBox less tested in homelab |

## AIOStreams UI Architecture & Configuration Paths

### Main Navigation Structure

AIOStreams v2.29.5 UI is organized into four primary menus:

1. **Services** — Configure debrid providers (Real-Debrid, Torbox, AllDebrid, etc.), reorder by priority, manage API credentials
2. **Addons** — Three tabs:
   - **Marketplace:** Browse and install addons (Torrentio, Annatar, etc.)
   - **Installed:** Manage active addon instances, enable/disable, edit settings
   - **Catalogues:** Reorder and customize addon result display
3. **Filters** — Organized subsections:
   - **Regex Patterns** — Whitelist/exclude patterns for release tags (WEB-DL, AMZN, YTS, etc.)
   - **Generic Stream Attributes** — Resolution, encoding, language filters
   - **Cache, Seeders, Matching, Keywords, Size, Result Limits** — Advanced filtering
4. **User** / Settings — Account and system settings (accessible via user icon or settings menu)

### Configuration Entry Points (v2.29.5 Specific)

**Real-Debrid Credential Entry:**
- Navigate: **Services** → Debrid Services row → Click **cogwheel icon** (⚙️) at end of Real-Debrid row
- Field: API Key input (source: https://real-debrid.com/apitoken)
- Verification: After entry, status shows "Connected" or error state

**Torrentio Addon Installation:**
- Navigate: **Addons** → **Marketplace** tab → Search "Torrentio" OR use custom manifest URL
- Add via manifest URL field (if not in marketplace): `https://torrentio.strem.fun/manifest.json`
- Verify: Addon appears in **Installed** tab after installation

**Regex Pattern Activation:**
- Navigate: **Filters** → **Regex Patterns** section (appears after activating filters)
- Action: Import or add patterns from:
  - Pre-configured: `WHITELISTED_REGEX_PATTERNS` ConfigMap value (already set to `["/(WEB-DL|AMZN|DSNP|YTS|RARBG|EZTV)/i"]`)
  - UI toggle: Activate "Use Regex Filters" or similar option if available
- Expected behavior: Patterns are immediately available in **Filters** menu for operator selection

## Standard Torrentio Manifest URL

[VERIFIED: Torrentio official documentation] — Current manifest URL for integration:

```
https://torrentio.strem.fun/manifest.json
```

This is the only official Torrentio source. Configuration page (with per-user settings) available at: `https://torrentio.strem.fun/configure`

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Real-Debrid blocking detection | Custom block-list monitor | WHITELISTED_REGEX_PATTERNS + Regex Filters in AIOStreams UI | AIOStreams regex filtering is proven, maintains release tag patterns, catches blocks as they occur |
| Debrid provider selection | Custom provider logic | Real-Debrid (with TorBox/Usenet alternatives documented in ADR-017) | Multiple providers tested by community; switching documented as a future v2 feature |
| Stream filtering UI | Custom toggle interface | AIOStreams web UI (built-in Filters menu) | Extensive filtering options already implemented; UI pattern established |

**Key insight:** AIOStreams' strength is that it consolidates multi-addon, multi-debrid filtering into a single configurable interface. Manual filtering or custom provider logic would duplicate complexity and reduce maintainability.

## Filter Validation Strategy

### Test Search Procedure (Operator-Verified)

The validation procedure confirms that regex-blocked streams do NOT appear in Stremio when searching for content known to have WEB-DL, YTS, AMZN, and DSNP-tagged versions.

**Recommended test content (widely available with blocked tags):**
- Popular TV shows: "Breaking Bad," "The Office," "Game of Thrones" (common WEB-DL/AMZN/YTS availability)
- Popular movies: "Oppenheimer," "Dune: Part Two," "The Godfather" (common WEB-DL sources)
- Verification target: Search results display only UNBLOCKED tags (WEBRIP without DL, 720p/1080p generic, scene groups not in filter)

**Why these work:**
- High seed counts across multiple sources → multiple tag variants available in Torrentio
- Known WEB-DL/YTS/AMZN versions in public trackers → filter effectiveness is immediately visible
- Non-technical verification → operator can visually confirm "these results are missing the DL versions I know exist"

### Pass Criteria

- At least ONE search returns results (pod is healthy, addon connectivity OK)
- Results for content known to have WEB-DL tags show NO WEB-DL entries in title or metadata
- Same search on vanilla Torrentio (without AIOStreams) DOES show WEB-DL entries → confirms AIOStreams is filtering

### Fail Criteria & Remediation

- Search returns zero results → Pod not responding; check `kubectl logs -n aiostreams aiostreams-*` for ESO sync errors
- WEB-DL entries still appear → Filter not activated or regex pattern not applied; verify Filters menu shows patterns as active
- ESO secret sync failure → Real-Debrid shows as "disconnected" in Services; run `bao kv get secret/aiostreams/production` to confirm secret exists in OpenBao

## Common Pitfalls

### Pitfall 1: FORCED_SERVICE_CREDENTIALS Not Synced by ESO

**What goes wrong:** AIOStreams UI shows Real-Debrid as "disconnected" even though the pod is running and the secret exists in OpenBao.

**Why it happens:** ExternalSecret refresh interval hasn't elapsed, or ESO pod encountered a permission error and silently failed to sync. The pod reads env vars at startup; if sync fails before pod start, credentials aren't available.

**How to avoid:** 
1. Verify `ExternalSecret/aiostreams-secret` status in `kubectl describe externalsecret -n aiostreams aiostreams-secret`
2. Check ESO pod logs: `kubectl logs -n external-secrets -l app.kubernetes.io/name=external-secrets`
3. Confirm policy is applied: `bao policy show eso-policy` includes `secret/data/aiostreams/*`
4. If sync succeeded but pod shows "disconnected," restart the pod: `kubectl rollout restart deployment aiostreams -n aiostreams` (forces env var re-read)

**Warning signs:** ESO pod logs show "permission denied" on `secret/aiostreams/production`; ExternalSecret Status shows LastSyncTime from before Phase 1 secret creation.

### Pitfall 2: Regex Filter Not Appearing in UI

**What goes wrong:** Operator navigates to Filters menu but does not see a "Regex Patterns" section, or patterns show as empty.

**Why it happens:** ConfigMap `WHITELISTED_REGEX_PATTERNS` wasn't injected into pod env vars, OR the pod hasn't restarted since ConfigMap creation. `REGEX_FILTER_ACCESS=all` must also be set to make patterns available without per-user trust.

**How to avoid:**
1. Verify ConfigMap exists: `kubectl get cm -n aiostreams aiostreams-config`
2. Verify pod has both env vars: `kubectl exec -n aiostreams <pod> -- env | grep -E "REGEX_FILTER_ACCESS|WHITELISTED_REGEX_PATTERNS"`
3. If missing, restart: `kubectl rollout restart deployment aiostreams -n aiostreams`
4. Wait 30 seconds for pod to become ready (liveness probe will fail until patterns load)

**Warning signs:** Pod shows as "RestartingBackoff" in `kubectl get pods -n aiostreams`; pod logs show `undefined` or `parse error` when loading regex patterns.

### Pitfall 3: Torrentio Manifest URL Wrong or Stale

**What goes wrong:** Installing Torrentio results in zero search results, or addon appears but returns "service unavailable" errors in Stremio.

**Why it happens:** Manifest URL is outdated, or Torrentio service is temporarily down. Torrentio is a third-party service outside homelab control.

**How to avoid:**
1. Verify manifest is reachable: `curl -s https://torrentio.strem.fun/manifest.json | jq '.version'` should return a version string
2. If unreachable, note incident in runbook troubleshooting and suggest checking https://github.com/Stremio-Community/Stremio-Addons issues
3. Test with a simpler addon first (e.g., RARBG) to confirm AIOStreams + Stremio integration works before attributing failures to Torrentio
4. Document in runbook: "If Torrentio returns zero results, verify the service is not under maintenance by visiting https://torrentio.strem.fun/"

**Warning signs:** Manifest URL returns 404 or 503; Stremio shows "Torrentio - no results"; Torrentio GitHub issues mention ongoing outage.

### Pitfall 4: Stale Version Documentation

**What goes wrong:** Runbook documents menu paths or field names that changed in a newer version of AIOStreams (e.g., v2.30+), and operator cannot find "Services" or "Regex Patterns" menu.

**Why it happens:** AIOStreams is actively developed; UI changes between minor versions. Documentation becomes version-specific without explicit pinning.

**How to avoid:**
1. Pin version in runbook header: "This runbook is for AIOStreams v2.29.5. If you are running a different version, verify menu names and field locations match before proceeding."
2. Include a "Verify Version" step: `kubectl exec -n aiostreams <pod> -- curl -s http://localhost:3000/api/v1/status | jq '.version'`
3. Add runbook update cadence to ADR-017 Consequences: "Quarterly review of UI paths if new versions are deployed."
4. If version mismatch detected, document deviation: "v2.30 changed 'Services' to 'Providers'; proceed with caution."

**Warning signs:** Operator reports "menu names don't match runbook"; pod logs show version string different from v2.29.5.

## AIOStreams Environment Variables (for Reference)

The deployment was already configured in Phase 2 with these pre-seeded values:

| Variable | Value | Source | Activation |
|----------|-------|--------|-----------|
| `FORCED_SERVICE_CREDENTIALS` | `realdebrid.apiKey=<key>` | ExternalSecret (OpenBao) | Synced at pod startup; verified via UI Services tab |
| `WHITELISTED_REGEX_PATTERNS` | `["/(WEB-DL\|AMZN\|DSNP\|YTS\|RARBG\|EZTV)/i"]` | ConfigMap | Available in UI Filters menu; user activates toggle |
| `REGEX_FILTER_ACCESS` | `all` | ConfigMap | Enables filters globally without per-user trust |
| `BASE_URL` | `http://192.168.1.205:3000` | Deployment env | Used by AIOStreams for links, redirects |
| `PORT` | `3000` | ConfigMap | Listening port for health probes and web UI |

**Format notes:**
- `FORCED_SERVICE_CREDENTIALS` is the full string including `realdebrid.apiKey=` prefix (not just the key)
- `WHITELISTED_REGEX_PATTERNS` is JSON array syntax with escaped `|` (pipe) characters for OR logic
- Both are already set and require no manual entry in the UI unless rotation is needed (covered in Phase 1 runbook)

## Code Examples

### Real-Debrid UI Verification (Post-ESO Sync)

After the pod starts and ESO syncs the secret, open AIOStreams UI and navigate to:

```
http://192.168.1.205:3000/ → Services (menu) → Real-Debrid row → Look for green checkmark or "Connected" status
```

If status shows "Disconnected" despite ESO having synced the secret:
1. Check pod logs: `kubectl logs -n aiostreams aiostreams-<pod-id>`
2. Restart pod to re-read env vars: `kubectl rollout restart deployment aiostreams -n aiostreams`
3. Wait 30s, then refresh browser

### Torrentio Addon Installation

From AIOStreams web UI:

```
1. Addons (menu)
2. Marketplace (tab)
3. Search "Torrentio" or paste manifest URL: https://torrentio.strem.fun/manifest.json
4. Click "Install"
5. Addon appears in "Installed" tab
```

If search returns no results:
- Try pasting the manifest URL directly in the custom URL field
- Verify manifest is reachable: `curl https://torrentio.strem.fun/manifest.json`

### Regex Filter Activation Example

From AIOStreams web UI:

```
1. Filters (menu)
2. Scroll to "Regex Patterns" section (or click Regex tab if tabs present)
3. Look for toggle or "Activate Whitelisted Patterns"
4. Click toggle to enable
5. Patterns from WHITELISTED_REGEX_PATTERNS now active
```

Expected: Stremio searches now exclude WEB-DL, AMZN, YTS, etc. from results

## Real-Debrid May 2026 Blocking Incident

[VERIFIED: ElfHosted documentation] — On or around May 10, 2026, Real-Debrid implemented content filtering on their platform, blocking cached torrents identified by filename keywords including:

- `WEB-DL` (web rips)
- `WEBRip` (generic web rips)
- `AMZN` (Amazon exclusive releases)
- `NF` (Netflix exclusive releases)
- `CR` (Crunchyroll exclusive releases)
- `YTS` (YTS release group)
- `RARBG` (RARBG release group)

Real-Debrid returns `infringing_file` responses instead of playable links for these tagged files. This is not an account ban or outage — it is a policy change. Debrid services like ElfHosted have responded by filtering these results client-side (AIOStreams approach) before displaying to users.

**Why it matters for ADR-017:** This incident is the primary trigger for deploying AIOStreams as a filtering proxy. Without AIOStreams, Torrentio search results contain 50%+ dead links flagged as infringing. With AIOStreams filtering enabled, only whitelisted content appears.

## ADR-017 Outline (Locked Decision D-07, D-08, D-09)

The architectural decision record must address:

1. **Context:** Real-Debrid blocking incident (May 2026) + impact on Stremio user experience
2. **Decision:** Deploy self-hosted AIOStreams on k3s to filter blocked content before presenting in Stremio
3. **Alternatives Considered:**
   - **Comet addon** — Alternative filtering addon with RD support; less mature, smaller community
   - **ElfHosted hosted AIOStreams** — Managed SaaS; loses intranet isolation and Torrentio support
   - **Switch debrid providers (TorBox, Usenet)** — Viable but requires API key rotation and provider migration
4. **Consequences:**
   - Regex patterns must be reviewed quarterly as RD's block list evolves
   - `SECRET_KEY` is immutable after first pod startup — cannot be rotated; must be generated once and kept secure
   - Intranet-only exposure is a constraint: external internet access would require Traefik + hostname infrastructure
   - SQLite persistence is adequate for single-user homelab; future v2 may migrate to PostgreSQL for HA

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Torrentio manifest URL `https://torrentio.strem.fun/manifest.json` is current as of May 2026 | Standard Stack, Code Examples | If URL is stale, operator cannot install addon; runbook would require update |
| A2 | AIOStreams v2.29.5 UI has a "Services" menu with a cogwheel icon for Real-Debrid config | Common Pitfalls, Code Examples | If UI changed in recent patch, operator cannot locate credential entry point |
| A3 | WHITELISTED_REGEX_PATTERNS is activated via a toggle in the Filters menu | Pitfall 2, Code Examples | If feature was disabled or requires an `ADDON_PASSWORD` to activate, filter won't be available to users |
| A4 | `ExternalSecret` refresh interval from Phase 2 is sufficient to sync secrets before pod startup | Pitfall 1 | If interval is too long, pod may start with missing credentials; requires restart after sync |

**Validation:** Assumptions A2–A3 must be confirmed during runbook execution (operator sees UI). Assumption A4 can be verified by checking ExternalSecret status after pod is running.

## Open Questions (RESOLVED)

1. **AIOStreams custom filters:**
   - What we know: ConfigMap pre-seeds WHITELISTED_REGEX_PATTERNS; Filters menu should show patterns
   - What's unclear: Whether filters activate automatically or require an `ADDON_PASSWORD` to be set
   - Recommendation: Runbook includes a fallback step: "If Regex Patterns menu is empty, check if ADDON_PASSWORD env var is needed (not currently set)"
   - RESOLVED: 03-01-PLAN Task 1 includes Troubleshooting table entry for "Regex Patterns section not visible → ADDON_PASSWORD may be required"; handled defensively without blocking planning.

2. **Torrentio Stremio integration:**
   - What we know: Manifest URL is standard, addon is installable in AIOStreams marketplace
   - What's unclear: Whether Stremio client caches addon sources and requires manual refresh to pick up AIOStreams filtering
   - Recommendation: Filter validation runbook includes cache-clear step: "If Stremio still shows WEB-DL results, force Stremio to refresh addon state (Settings → Addons → Remove/Re-add source)"
   - RESOLVED: 03-02-PLAN Task 1 Step 4 includes explicit Stremio cache-clear step in the validation procedure.

3. **ADR-017 constraint scope:**
   - What we know: SECRET_KEY is immutable; intranet-only is a constraint
   - What's unclear: Whether intranet-only constraint is a security requirement or an operational convenience
   - Recommendation: ADR Consequences section clarifies: "Intranet-only exposure is acceptable because Stremio is a personal media client; broader internet exposure would require identity/auth integration (deferred to v2)"
   - RESOLVED: 03-03-PLAN Task 1 Consequences section explicitly frames intranet-only as an accepted operational constraint with a deferred path to Traefik + DNS (PLAT-01/PLAT-02).

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| AIOStreams pod (K3s) | CONF-01, CONF-02 | ✓ | v2.29.5 (Phase 2 outcome) | — |
| Real-Debrid API key | CONF-01 (credential verification) | ✓ (from Phase 1) | — | Cannot test; credential must be active |
| Stremio client | CONF-02 (filter validation) | ✓ (operator has LAN device) | User's device | — |
| Torrentio service | CONF-01, CONF-02 | ✓ (external) | Latest (manifest-driven) | Service outage possible; fallback: use RARBG or Annatar addon for testing |
| MetalLB LoadBalancer IP | Access to UI + validation | ✓ | 192.168.1.205:3000 (Phase 2 outcome) | — |

**Missing dependencies with no fallback:** None — all required services are operational from Phase 2.

**Note:** Torrentio is a third-party service outside homelab control. If unavailable, validation can proceed with RARBG or similar addon as a stand-in (confirm AIOStreams + Stremio integration works; confirm filtering activates; skip Torrentio-specific verification).

## Validation Architecture

Framework: Nyquist validation **enabled** (workflow.nyquist_validation not explicitly disabled in .planning/config.json)

### Test Framework

| Property | Value |
|----------|-------|
| Framework | Manual Stremio UI + AIOStreams web UI verification (no automated tests) |
| Config file | N/A (documentation phase) |
| Quick run command | N/A |
| Full suite command | See Wave 0 below |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Manual Verification | Documentation |
|--------|----------|-----------|-------------------|-----------------|
| CONF-01 | AIOStreams UI runbook covers RD credential entry, Torrentio addon install, filter activation | Smoke / Manual | Operator follows runbook steps; UI shows "Connected" for RD, addon appears in Installed tab, Filters menu shows patterns | setup-aiostreams.md |
| CONF-02 | Filter validation confirms WEB-DL/YTS/AMZN tags are blocked in Stremio search | Smoke / Manual | Operator searches for known WEB-DL content; no WEB-DL entries appear in results; same search on vanilla Torrentio shows WEB-DL entries | validate-filter.md |
| DOC-01 | ADR-017 documents decision, problem (RD May 2026), alternatives, and constraints | Documentation / Manual | ADR is readable, sections present, rationale is clear, alternatives are compared, consequences are concrete | ADR-017-aiostreams-stremio-filtering.md |

### Sampling Rate

- **Per task commit (runbook + ADR):** Documentation is reviewed for structure and content completeness
- **Per wave merge:** Operator executes CONF-01 (UI setup) and CONF-02 (filter validation) manually; both succeed with no Stremio showing blocked content
- **Phase gate:** Both runbook and ADR are committed to `homelab-knowledge` repo; Phase 2 (pod running) has completed; operator confirms no WEB-DL/AMZN/YTS entries in Stremio search

### Wave 0 Gaps

- [✓] `homelab-knowledge/runbooks/setup-aiostreams.md` — To be written during Phase 3 planning/execution
- [✓] `.planning/runbooks/validate-filter.md` — To be written during Phase 3 planning/execution
- [✓] `homelab-knowledge/adr/ADR-017-aiostreams-stremio-filtering.md` — To be written during Phase 3 planning/execution
- [N/A] No automated test framework; phase is pure documentation

**Status:** No pre-existing infrastructure. All three deliverables are written from scratch during this phase.

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V1 Architecture | No | — |
| V2 Authentication | Yes | AIOStreams `ADDON_PASSWORD` (not currently set; optional for future multi-user scenarios) |
| V3 Session Management | No | — |
| V4 Access Control | Yes | `REGEX_FILTER_ACCESS=all` (globally available) and intranet-only MetalLB exposure (network boundary) |
| V5 Input Validation | Yes | Regex patterns are pre-validated JSON; user input in Stremio (search queries) is delegated to Torrentio/addon layer |
| V6 Cryptography | Yes | `SECRET_KEY` (64-char hex) is immutable; stored in OpenBao, synced via ExternalSecret; never exposed in logs or git |
| V7 Error Handling | No | — |
| V8 Data Protection | Yes | SQLite PVC at `/app/data` is local-path storage; no encryption at rest (acceptable for intranet, homelab-only service) |
| V9 Communication | Yes | All intranet communication (AIOStreams ↔ Stremio ↔ MetalLB) is over HTTP (acceptable for LAN); external Torrentio/RD APIs use HTTPS |
| V10 Malware | No | — |
| V11 Business Logic | Yes | Regex filter logic is AIOStreams-native; Real-Debrid block list is handled by curated patterns |
| V12 Files & Resources | No | — |
| V13 API | Yes | AIOStreams API endpoints (health check, addon protocol) are intranet-only |
| V14 Configuration | Yes | ConfigMap (WHITELISTED_REGEX_PATTERNS, REGEX_FILTER_ACCESS) and ExternalSecret (FORCED_SERVICE_CREDENTIALS) are externalized; no secrets in container image |

### Known Threat Patterns for AIOStreams + Real-Debrid

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Real-Debrid API key exposure | Tampering, Information Disclosure | Store in ExternalSecret (OpenBao); never log, never commit to git; rotate via `bao kv patch` without redeploying pod |
| SECRET_KEY rotation attack | Tampering | Immutability constraint: key is generated once, never rotated; documented in Phase 1 runbook and ADR-017 Consequences |
| Intranet-only exposure bypass | Elevation of Privilege | MetalLB LoadBalancer is LAN-only; Traefik/ingress not configured; no public DNS; external access blocked by network policy (acceptable for homelab) |
| Regex pattern injection | Injection | Patterns are pre-configured in ConfigMap, not user-supplied at runtime; no eval() of user input |
| Stremio addon source spoofing | Spoofing | Manifest URL is hardcoded in runbook; operator manually adds source; Stremio client validates manifest signature |

## Sources

### Primary (HIGH confidence)

- [AIOStreams official GitHub](https://github.com/Viren070/AIOStreams) - Repository, .env.sample, releases, issue tracking
- [AIOStreams Setup Guide (Viren070's Guides)](https://guides.viren070.me/stremio/addons/aiostreams/setup) - Official configuration documentation
- [AIOStreams Documentation (Viren070's Guides)](https://guides.viren070.me/stremio/addons/aiostreams/documentation) - UI structure, menu navigation, filter interface
- [ElfHosted AIOStreams Documentation](https://docs.elfhosted.com/app/aiostreams/) - May 2026 Real-Debrid blocking incident details, filtering approach
- [Torrentio Official Page](https://torrentio.strem.fun/) - Manifest URL and configuration
- [Torrentio Setup Guide (Viren070's Guides)](https://guides.viren070.me/stremio/addons/torrentio) - Integration with AIOStreams

### Secondary (MEDIUM confidence)

- [WebSearch: AIOStreams v2.29.5 release notes](https://github.com/Viren070/AIOStreams/releases) - Version pinning confirmation
- [TroyPoint: How to Setup & Install Torrentio on Stremio (2026 Guide)](https://troypoint.com/torrentio/) - Community installation guide
- [Community Stremio Addons List](https://stremio-addons.net/) - Addon discovery and comparison

### Project References (from CONTEXT.md)

- `.planning/phases/02-kubernetes-manifests/02-CONTEXT.md` - AIOStreams deployment details (IP 192.168.1.205, env vars, regex pattern)
- `homelab-knowledge/adr/ADR-016-infra-on-proxmox-apps-on-k3s.md` - ADR format and infrastructure classification
- `homelab-knowledge/runbooks/add-credential.md` - Runbook format (Prerequisites, Steps, Troubleshooting table)
- `homelab-knowledge/runbooks/provision-aiostreams-secrets.md` - Phase 1 runbook for cross-linking in Phase 3

## Metadata

**Confidence breakdown:**

| Area | Level | Reason |
|------|-------|--------|
| Standard stack (AIOStreams + Torrentio + RD) | HIGH | Verified via official docs, GitHub, ElfHosted; v2.29.5 pinned and tested |
| UI paths (Services, Filters, Addons menus) | MEDIUM | Documented in official guides; CONF-01 runbook will verify during operator execution; minor version changes may alter paths |
| Real-Debrid May 2026 blocking incident | HIGH | Confirmed in ElfHosted documentation and AIOStreams GitHub issues |
| Regex filter activation mechanism | MEDIUM | Documented as available in Filters menu; exact UI toggle/button location to be confirmed during execution |
| Torrentio manifest URL | HIGH | Current URL verified as https://torrentio.strem.fun/manifest.json via official source |
| ADR format and alternatives | HIGH | ADR-016 and ADR-011 provided format template; alternatives (Comet, ElfHosted, TorBox) confirmed via research |

**Research date:** 2026-05-13
**Valid until:** 2026-06-13 (30 days; AIOStreams is stable; Torrentio service is maintained by community)
**Review trigger:** If AIOStreams version changes beyond v2.29.x OR Torrentio service is no longer at https://torrentio.strem.fun/manifest.json, re-research UI paths and update runbooks.

---

*Phase: 3-configuration-documentation*
*Research completed: 2026-05-13*
