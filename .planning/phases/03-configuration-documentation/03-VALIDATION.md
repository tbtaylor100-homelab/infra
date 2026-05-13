---
phase: 3
slug: configuration-documentation
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-05-13
---

# Phase 3 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Manual only — pure documentation phase, no automated test framework |
| **Config file** | N/A |
| **Quick run command** | N/A — verify file existence and structure manually |
| **Full suite command** | See Manual-Only Verifications below |
| **Estimated runtime** | ~10 minutes (operator UI walkthrough) |

---

## Sampling Rate

- **After every task commit:** Verify file was created at the correct path with correct structure
- **After every plan wave:** Operator follows setup-aiostreams.md runbook; confirms UI steps match live AIOStreams v2.29.5 UI
- **Before `/gsd-verify-work`:** All three deliverables committed to `homelab-knowledge` repo; filter validation runbook executed and passing

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| UI setup runbook | 01 | 1 | CONF-01 | — | No secrets in runbook content; RD API key referenced by path only | manual | `test -f ../homelab-knowledge/runbooks/setup-aiostreams.md` | ❌ W0 | ⬜ pending |
| Filter validation runbook | 01 | 1 | CONF-02 | — | N/A (documentation) | manual | `test -f .planning/runbooks/validate-filter.md` | ❌ W0 | ⬜ pending |
| ADR-017 | 02 | 1 | DOC-01 | — | No secrets or keys in ADR content | manual | `test -f ../homelab-knowledge/adr/ADR-017-aiostreams-stremio-filtering.md` | ❌ W0 | ⬜ pending |
| homelab-knowledge push | 02 | 2 | CONF-01, DOC-01 | — | N/A | manual | `cd ../homelab-knowledge && git log --oneline -1` | N/A | ⬜ pending |
| Filter validation execution | 02 | 2 | CONF-02 | — | Stremio shows no WEB-DL/YTS/AMZN entries for tested content | manual | See operator steps below | N/A | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `homelab-knowledge/runbooks/setup-aiostreams.md` — Created during Wave 1; path verified at `../homelab-knowledge/runbooks/`
- [ ] `.planning/runbooks/validate-filter.md` — Created during Wave 1
- [ ] `homelab-knowledge/adr/ADR-017-aiostreams-stremio-filtering.md` — Created during Wave 1

*If none: "Existing infrastructure covers all phase requirements." — Not applicable; all three deliverables are written from scratch.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| AIOStreams UI runbook covers RD credential entry, Torrentio addon install, and filter activation | CONF-01 | UI interaction with deployed service; no API equivalent | Operator opens `http://192.168.1.205:3000`, follows setup-aiostreams.md; confirms "Connected" RD status; Torrentio appears in Installed tab; Filters menu shows regex patterns |
| Filter validation confirms WEB-DL/YTS/AMZN tags are blocked | CONF-02 | Requires live Stremio client + Torrentio | Operator searches "Breaking Bad" or "Oppenheimer" in Stremio; confirms no WEB-DL/YTS/AMZN entries in results; searches same on vanilla Torrentio and confirms entries ARE present (baseline) |
| ADR-017 structure complete and readable | DOC-01 | Prose quality and completeness review | Reviewer opens ADR; confirms all 5 sections present (Context, Decision, Alternatives, Consequences, Status); rationale is specific to May 2026 RD blocking event; alternatives are compared with trade-offs |
| homelab-knowledge changes pushed to remote | CONF-01, DOC-01 | Requires separate git push to homelab-knowledge repo | `cd ../homelab-knowledge && git log --oneline -3` shows setup-aiostreams.md and ADR-017 commits; `git status` is clean |

---

## Validation Sign-Off

- [ ] All three deliverables created at correct paths
- [ ] homelab-knowledge repo committed and pushed to `ssh://git@192.168.1.50:2222/tbtaylor100/homelab-knowledge.git`
- [ ] Operator executed CONF-01 runbook steps against live AIOStreams UI
- [ ] Operator executed CONF-02 filter validation — Stremio shows no blocked tags
- [ ] ADR-017 reviewed for completeness and accuracy
- [ ] `nyquist_compliant: true` set in frontmatter after sign-off

**Approval:** pending
