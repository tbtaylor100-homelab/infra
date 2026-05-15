---
phase: "03"
plan: "02"
subsystem: documentation
tags: [validation, filter, stremio, aiostreams, conf-02]
key-files:
  created:
    - ".planning/runbooks/validate-filter.md"
metrics:
  tasks_completed: 1
  tasks_total: 1
---

# Plan 03-02 Summary: Filter Validation Procedure

## What Was Built

Wrote the one-time filter validation procedure at `.planning/runbooks/validate-filter.md`. This project artifact (not a reusable operational runbook) documents how an operator confirms the AIOStreams regex exclusion filter is working: search for content known to have WEB-DL/YTS/AMZN versions and verify those streams do not appear in Stremio.

## Commits

| Task | File | Description |
|------|------|-------------|
| Task 1 | .planning/runbooks/validate-filter.md | Written (commit to infra repo deferred to Plan 03-04 Task 2) |

## Key Decisions

- Stremio UI only per D-02 — no curl/API testing required in the main procedure
- Names specific search examples: Breaking Bad, The Office, Game of Thrones (TV); Oppenheimer, Dune Part Two, The Godfather (movies)
- Includes optional baseline comparison step: temporarily add vanilla Torrentio to confirm AIOStreams is the source of filtering
- Includes Stremio cache-clear fallback (Step 4) per RESEARCH.md Open Question 2 resolution
- Fail Criteria table has three columns: Symptom | Likely cause | Remediation (kubectl diagnostics in remediation are acceptable per D-02)

## Deviations

None — followed plan specification exactly.

## Verification Results

```
ls .planning/runbooks/validate-filter.md → exists (PASS)
grep -c 'Breaking Bad\|Oppenheimer\|Dune' → 2 (PASS)
grep -c 'Pass Criteria\|Fail Criteria' → 2 (PASS)
grep -c 'setup-aiostreams' → 2 (cross-link present, PASS)
```

## Self-Check: PASSED

All acceptance criteria met:
- [x] .planning/runbooks/ directory exists
- [x] .planning/runbooks/validate-filter.md exists
- [x] "# Filter Validation Procedure" as H1 title
- [x] References setup-aiostreams.md in Prerequisites
- [x] Names specific search examples (Breaking Bad, Oppenheimer, Dune Part Two, etc.)
- [x] Lists explicit pass criteria: no WEB-DL/AMZN/DSNP/YTS/RARBG/EZTV in stream results
- [x] Contains fail criteria table with remediation steps
- [x] Includes Stremio cache-clear fallback step
- [x] Validation method is Stremio UI only (no curl/API testing required per D-02)
