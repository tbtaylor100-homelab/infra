---
phase: "03"
plan: "01"
subsystem: documentation
tags: [runbook, aiostreams, stremio, real-debrid, conf-01]
key-files:
  created:
    - "../homelab-knowledge/runbooks/setup-aiostreams.md"
metrics:
  tasks_completed: 1
  tasks_total: 1
---

# Plan 03-01 Summary: AIOStreams Setup Runbook

## What Was Built

Wrote the AIOStreams post-deploy UI setup runbook at `homelab-knowledge/runbooks/setup-aiostreams.md`. This permanent operational document guides an operator through five steps: verifying AIOStreams pod health, confirming Real-Debrid connectivity via the Services menu, installing the Torrentio addon from the Marketplace, activating the pre-configured regex exclusion filter, and adding AIOStreams as a Stremio addon source.

## Commits

| Task | File | Description |
|------|------|-------------|
| Task 1 | homelab-knowledge/runbooks/setup-aiostreams.md | Written (commit in homelab-knowledge repo deferred to Plan 03-04 Task 1) |

## Key Decisions

- Version pinned to v2.29.5 in the opening paragraph per D-05
- Cross-links `provision-aiostreams-secrets.md` in both the note block and Prerequisites per D-04
- Notes that `WHITELISTED_REGEX_PATTERNS` is pre-configured — operator only activates the toggle, does not re-enter the regex per CONTEXT.md Specifics
- Troubleshooting table follows `add-credential.md` format (Symptom | Likely cause)
- No credential values embedded — only env var names and verification commands

## Deviations

None — followed plan specification exactly.

## Verification Results

```
grep -c 'v2.29.5' setup-aiostreams.md → 4 (PASS)
grep -c 'provision-aiostreams-secrets' setup-aiostreams.md → 2 (PASS)
grep -c 'torrentio.strem.fun' setup-aiostreams.md → 3 (PASS)
grep for credential values → 0 (PASS — no secrets in document)
```

## Self-Check: PASSED

All acceptance criteria met:
- [x] File exists at homelab-knowledge/runbooks/setup-aiostreams.md
- [x] Title "# Runbook: Set Up AIOStreams After Deployment" with "Runbook:" prefix
- [x] Contains "v2.29.5" version pin
- [x] Contains reference to provision-aiostreams-secrets.md as prerequisite
- [x] Contains Torrentio manifest URL https://torrentio.strem.fun/manifest.json
- [x] Steps cover: Real-Debrid verification, Torrentio installation, filter activation, Stremio source addition
- [x] Notes that WHITELISTED_REGEX_PATTERNS is pre-configured (operator activates toggle only)
- [x] Troubleshooting table with Symptom | Likely cause columns
- [x] No embedded credential values
