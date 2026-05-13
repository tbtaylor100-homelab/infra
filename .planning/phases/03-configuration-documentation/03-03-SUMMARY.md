---
phase: "03"
plan: "03"
subsystem: documentation
tags: [adr, aiostreams, architecture, decision-record, doc-01]
key-files:
  created:
    - "../homelab-knowledge/adr/ADR-017-aiostreams-stremio-filtering.md"
metrics:
  tasks_completed: 1
  tasks_total: 1
---

# Plan 03-03 Summary: ADR-017 Architectural Decision Record

## What Was Built

Wrote ADR-017 at `homelab-knowledge/adr/ADR-017-aiostreams-stremio-filtering.md`. This architectural decision record documents the May 2026 Real-Debrid blocking incident (2026-05-10: `infringing_file` responses for WEB-DL/AMZN/YTS/RARBG/EZTV), the decision to deploy self-hosted AIOStreams v2.29.5 on K3s, three alternatives considered, and key consequences including SECRET_KEY immutability and the quarterly regex review cadence.

## Commits

| Task | File | Description |
|------|------|-------------|
| Task 1 | homelab-knowledge/adr/ADR-017-aiostreams-stremio-filtering.md | Written (commit in homelab-knowledge repo deferred to Plan 03-04 Task 1) |

## Key Decisions

- Followed ADR-016 format: Status, Date, Context, Decision, Alternatives Considered (explicit section per D-07), Consequences
- Context section names May 2026 blocking incident with specific date (2026-05-10) per RESEARCH.md
- All three alternatives addressed per D-08: Comet, ElfHosted hosted AIOStreams, switching debrid providers (TorBox/Usenet)
- Decision references ADR-016 classification: AIOStreams is a K3s application (user-facing, nothing else depends on it)
- Consequences section explicitly covers: SECRET_KEY immutability, quarterly regex review cadence, intranet-only exposure constraint, SQLite adequacy for single-user
- No credential values in document — SECRET_KEY described as a policy constraint, not a value

## Deviations

None — followed plan specification exactly.

## Verification Results

```
grep -c 'ADR-017' ADR-017-aiostreams-stremio-filtering.md → 1 in title (PASS)
grep -c 'Comet\|ElfHosted\|TorBox' → 9 (all three alternatives present, PASS)
grep -c 'SECRET_KEY\|infringing\|May 2026\|2026-05-10' → 5 (PASS)
grep for credential values → 0 (no secrets in document, PASS)
```

## Self-Check: PASSED

All acceptance criteria met:
- [x] File exists at homelab-knowledge/adr/ADR-017-aiostreams-stremio-filtering.md
- [x] H1 title contains "ADR-017"
- [x] ## Status: Accepted
- [x] ## Date: 2026-05-13
- [x] ## Context references May 2026 Real-Debrid blocking incident with specific date (2026-05-10)
- [x] ## Alternatives Considered covers all three: Comet, ElfHosted, provider switching (TorBox/Usenet)
- [x] ## Decision contains the bold decision statement for self-hosted AIOStreams
- [x] ## Consequences mentions: SECRET_KEY immutability, quarterly regex review, intranet-only exposure constraint
- [x] ADR covers deployment decision scope only per D-07 (no SQLite schema, ConfigMap keys, or sync wave details)
- [x] No literal credential values embedded
