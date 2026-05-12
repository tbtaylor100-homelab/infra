# Feature Landscape: AIOStreams Stremio Filtering Proxy

**Domain:** Real-Debrid content filtering for self-hosted Stremio aggregation proxy  
**Use Case:** Single homelab operator filtering blocked RD content before Stremio display  
**Researched:** May 11, 2026

## Executive Summary

AIOStreams is a production-ready addon aggregator that consolidates Torrentio and other Stremio addons into a single proxy with advanced filtering. For Real-Debrid blocking use case, table stakes features are: regex pattern filtering, exclude/include filter modes, Stream Expression Language (SEL) for conditional exclusions, and Real-Debrid credential management. The project provides two primary filtering mechanisms—simple regex patterns (UI-driven) and advanced SEL-based excluded stream expressions (code-driven)—both of which can address RD blocking at different complexity levels.

**Key findings:**
- Regex filtering is self-hosted-only (security/abuse prevention) but fully mature
- WHITELISTED_REGEX_PATTERNS is pre-configured at deploy time; UI patterns are per-session
- Filtering is exclude-matching (removes streams matching criteria), not include-matching
- Torrentio requires custom URL format; no API key needed (auth via RD creds)
- Real-Debrid blocking patterns evolve rapidly; pattern maintenance will be ongoing

## Table Stakes Features

Features without which AIOStreams cannot fulfill the RD filtering use case.

| Feature | Why Required | Implementation | Maturity |
|---------|--------------|-----------------|----------|
| **Regex Pattern Filtering** | Core mechanism to exclude RD-blocked content (YTS, RARBG, WEB-DL, etc.) | Self-hosted instances only; `REGEX_FILTER_ACCESS` environment variable + UI toggles | Stable, production-ready |
| **Addon Aggregation** | Must consolidate Torrentio streams with other sources into unified list | Marketplace addon installer + custom URL addon support | Stable, 80+ addons supported |
| **Real-Debrid Integration** | Must accept RD API key and apply it across all compatible addons | Services configuration menu; one-time credential entry | Stable, encrypted via SECRET_KEY |
| **Exclude Filter Mode** | Must remove (not just rank) streams matching block patterns | Filter type selector in UI: Include/Exclude/Require/Prefer | Stable, revamped in v2.0 |
| **Deduplication** | Prevent duplicate streams from multiple addons cluttering results | Deduplicator with fuzzy match, infoHash, or smartDetect modes | Stable, per-service or per-addon grouping |
| **Torrentio as Source Addon** | Primary torrent source; must accept Torrentio manifest URL | Custom addon support via manifest URL (no API key needed) | Stable |
| **Stream Expression Language (SEL)** | Advanced conditional exclusions for nuanced RD filtering | Code-based excluded stream expressions; auto-update via URLs | Stable, full documentation available |

## Optional/Nice-to-Have Features

Features that enhance filtering sophistication but aren't mandatory for basic RD blocking.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|-----------|-------|
| **Cached Status Filtering** | Prioritize cached (instant playback) RD streams over uncached torrents | Low | Built-in; quick UX improvement |
| **Quality/Resolution Ranking** | Sort by resolution/quality to surface best streams first | Low | Configurable sort order; standard Stremio filtering |
| **Seeder Count Filtering** | Exclude low-seeder torrents to improve success rate | Low | Built-in seeder range filters |
| **Visual Tag Filtering** | Filter by HDR/DV/Dolby Vision tags | Medium | Useful for high-end home theater but not critical for RD filtering |
| **Language Filtering** | Multi-language sorting and exclusion | Low | Standard Stremio feature |
| **Catalog Management** | Rename, reorder, shuffle Stremio catalog | Low | UI convenience; no impact on filtering logic |
| **Custom Templates** | Reformat stream display (title, metadata shown) | Medium | Cosmetic; improves readability but doesn't affect filtering |
| **Groups (Conditional Addon Sets)** | Run different addon combinations for different content types (e.g., anime vs movies) | High | Advanced use case; requires SEL understanding |
| **Syndication/Merging Catalogs** | Merge catalogs from multiple addons | Medium | Not needed for single-user homelab filtering |
| **SEL Sync URLs** | Auto-update excluded stream expressions from remote sources | Medium | Optional if manual SEL maintenance is acceptable |

## Required Configuration (Deploy-Time vs. UI-Time)

### Deploy-Time (Environment Variables)

Must be set before container start:

| Variable | Purpose | Example |
|----------|---------|---------|
| `SECRET_KEY` | Encrypts debrid credentials in manifest URLs | 64-character hexadecimal string (required) |
| `WHITELISTED_REGEX_PATTERNS` | Pre-configured patterns available to all users | JSON array: `["/pattern1/flags", "/pattern2/flags"]` |
| `WHITELISTED_REGEX_PATTERNS_URLS` | Fetch patterns from external URLs (auto-update) | Array of URLs; patterns merge with hardcoded ones |
| `REGEX_FILTER_ACCESS` | Who can create custom regex (not whitelisted ones) | Options: "none", "trusted", "all" |
| `ADDON_PASSWORD` | Enable regex filter UI options (if not set, filters hidden) | String; acts as per-session enabler |

**Note:** `WHITELISTED_REGEX_PATTERNS` is deployed as static patterns; users cannot modify them. If you want user-editable patterns, users set `REGEX_FILTER_ACCESS` and `ADDON_PASSWORD` at deploy time, then regex filters appear in UI.

### Post-Deploy UI Configuration (One-Time)

User must perform these steps after deployment via `/stremio/configure` page:

1. **Services Menu** → Enter Real-Debrid API key (click cogwheel icon on RD row)
2. **Addons Menu** → Add Torrentio via custom URL (marketplace won't show it; must use manifest URL from Torrentio-enabled source)
3. **Filters Menu** (if `ADDON_PASSWORD` set) → Configure regex exclusion patterns and other filters
4. **Filtering & Sorting** → Adjust deduplicator, sort order, cached/uncached split
5. **Save & Install** → Create configuration, copy UUID/password for persistence

## Torrentio Integration

### Manifest URL Format

Torrentio requires a manifest URL, not an API key. Two options:

**Option A: Wrap Public Instance (Recommended for RD blocking)**
```
https://<torrentio-aiostreams-instance>/manifest.json
```
- Use a Torrentio-enabled public AIOStreams instance (not ElfHosted)
- Paste manifest URL into AIOStreams Addons menu → Custom addon
- RD credentials flow through your AIOStreams instance to Torrentio

**Option B: Direct Torrentio**
```
https://torrentio.strem.fun/manifest.json
```
- Direct connection to Torrentio (may have rate limits without wrapper)
- Less integrated with your filtering pipeline

**Important Note:** ElfHosted AIOStreams does NOT allow Torrentio due to licensing. If using ElfHosted as primary instance, wrap a Torrentio-enabled public instance within it using "Wrap AIOStreams within AIOStreams!" addon.

### URL Structure

Custom addons accept either:
- Full manifest URL: `https://example.com/manifest.json`
- Domain only: `https://example.com/` (AIOStreams auto-appends `/manifest.json`)

## Filter Mechanics

### Regex Filtering: Exclude-Matching (Not Include-Matching)

**Behavior:** Regex patterns remove streams matching the pattern.

**Filter Types (UI Toggle):**
- **Include:** Protects matching streams from ALL other exclusions (exception layer)
- **Exclude:** Removes matching streams (primary behavior)
- **Require:** Only keeps matching streams (inverse of exclude)
- **Prefer:** Ranks matching streams higher in sort order (no exclusion)

**Pattern Order Matters:** In the UI, regex pattern order determines ranking precedence when multiple patterns match. First pattern gets highest rank.

**Scope:** Matches against filenames, release group names, indexer names, and addon identifiers.

### WHITELISTED_REGEX_PATTERNS Behavior

**Deploy-time vs. UI-time distinction:**

- `WHITELISTED_REGEX_PATTERNS` (env var): Pre-loaded at startup; available to all users regardless of `REGEX_FILTER_ACCESS` setting; **static, not editable via UI**
- UI regex filters (if `ADDON_PASSWORD` set): Per-session, user-editable, stored in user's configuration UUID

**Use case for WHITELISTED_REGEX_PATTERNS:**
- Pre-apply organization-wide exclusions at deploy time (e.g., "always exclude RARBG for licensing reasons")
- Acts as a guardrail; users cannot override whitelisted patterns
- Useful for managed deployments where admin wants consistent filtering across all users

**For your single-user homelab:** You can either:
1. Set static patterns in `.env` and redeploy to change them (less flexible)
2. Skip `WHITELISTED_REGEX_PATTERNS` and configure everything in UI with `ADDON_PASSWORD` (more flexible, recommended)

### Stream Expression Language (SEL) for Advanced Exclusion

**Purpose:** Conditional, multi-criteria exclusions using a purpose-built expression language.

**Location:** Excluded Stream Expressions section in UI (code editor, not form builder).

**Example (exclude uncached RD streams with low seeders, except well-ranked releases):**
```sel
!cached(streams) && seeder(streams) < 10 && !regex(streams, /Vidhin|TRaSH-matched/)
```

**Key Functions:**
- `cached(streams)` — filter to cached debrid results
- `service(streams, 'realdebrid')` — filter by RD specifically
- `regex(streams, /pattern/)` — match against release name
- `seeder(streams)` — numeric seeder count
- `resolution(streams, '1080p')` — filter by resolution
- `size(streams) > 5000` — file size in MB

**Supported Services for SEL:** 'realdebrid', 'debridlink', 'alldebrid', 'torbox', 'pikpak', 'seedr', 'offcloud', 'premiumize', 'easynews', 'easydebrid'

**SEL Sync URLs:** Can configure `SEL_SYNC_ACCESS=all` and use URLs to auto-update excluded expressions from GitHub or other sources (useful for community-maintained RD block patterns).

## Recommended Regex Pattern for May 2026 RD Blocking

Based on ElfHosted community patterns and current RD blocking (as of May 2026):

```regex
/(\[(rartv|rarbg|eztv)\]|-(rartv|rarbg|eztv)\b|\b(YTS|Erai-raws|WEBRip|WEB-DL|AMZN|DSNP|CR)\b)/i
```

**Components:**
- `\[(rartv|rarbg|eztv)\]` — Square bracket release group tags (most common)
- `-(rartv|rarbg|eztv)\b` — Dash-separated group names
- `(YTS|Erai-raws|WEBRip|WEB-DL|AMZN|DSNP|CR)` — Known RD-blocked source tags
- `/i` flag — Case-insensitive matching

**What it matches (and excludes):**
- `[RARBG] Movie Title` → EXCLUDED
- `release-EZTV` → EXCLUDED
- `Movie.WEB-DL.1080p` → EXCLUDED
- `Movie.AMZN.1080p` → EXCLUDED
- `Movie.DSNP.1080p` → EXCLUDED
- `Movie.YTS` → EXCLUDED

**What it does NOT match:**
- Legitimate cached RD releases (no tag)
- High-quality source groups (must add custom pattern for each)

**Important:** This pattern is community-maintained and evolves as RD blocking changes. Plan for monthly/quarterly reviews. Set `WHITELISTED_REGEX_PATTERNS_URLS` to fetch updates from community sources if available, or manually update pattern in `.env` during patches.

### Alternative: SEL-Based Exclusion (More Flexible)

If you want to exclude RD-blocked content only for RD service (not for other debrid services if you add them later):

```sel
service(streams, 'realdebrid') && regex(streams, /(\[(rartv|rarbg|eztv)\]|-(rartv|rarbg|eztv)\b|\b(YTS|Erai-raws|WEBRip|WEB-DL|AMZN|DSNP|CR)\b)/i)
```

This excludes the pattern ONLY for Real-Debrid streams, allowing non-RD results (like Usenet) to bypass the filter if needed.

## Post-Deploy UI Setup (One-Time, Interactive Steps)

After container starts successfully at `http://<ip>:3000`:

### Step 1: Create Configuration (Save & Install Tab)
1. Navigate to `/stremio/configure`
2. Click "Configure" (white button)
3. Go to "Save & Install" tab
4. Enter a password (becomes your config PIN)
5. Click "Create"
6. **Copy and save the UUID and password** — you'll need these to reload config later

### Step 2: Add Real-Debrid Credentials (Services Tab)
1. Return to "Configure" menu
2. Go to "Services" tab
3. Find "Real-Debrid" row
4. Click cogwheel icon at end of row
5. Paste your RD API key
6. Confirm/save

### Step 3: Add Torrentio (Addons Tab)
1. Go to "Addons" tab
2. Look for "Custom" addon at top of list (not in marketplace)
3. Click "Custom"
4. Paste Torrentio manifest URL:
   - **If using Torrentio-enabled public AIOStreams:** `https://<instance>/manifest.json`
   - **If using direct Torrentio:** `https://torrentio.strem.fun/manifest.json`
5. Click "Install"

### Step 4: Configure Regex Filters (Filters Tab) — ONLY if ADDON_PASSWORD Set
1. Go to "Filters" tab
2. Look for "Regex Patterns" section (only visible if `ADDON_PASSWORD` env var was set at deploy time)
3. **Exclude Pattern:** Add your RD block pattern:
   ```
   /(\[(rartv|rarbg|eztv)\]|-(rartv|rarbg|eztv)\b|\b(YTS|Erai-raws|WEBRip|WEB-DL|AMZN|DSNP|CR)\b)/i
   ```
4. Click "Add" or "Apply"

### Step 5: Configure Deduplication & Sorting (Cached/Uncached Tabs)
1. Go to "Cached" tab (or "Uncached" for fallback behavior)
2. Enable "Deduplicator"
3. Set "Group Handling" to "Single Result" (consolidate duplicates across addons)
4. Set sort order (recommended: Cached → Library → Resolution → Quality → Regex Patterns → Visual Tag → Size → Seeder)

### Step 6: Finalize & Test
1. Go to "Save & Install" tab
2. Verify password and click "Update" or "Re-create"
3. Install to Stremio using the manifest URL shown
4. Search for a movie/show known to have RD-blocked sources (e.g., YTS release)
5. Verify blocked sources are excluded from results

## Features to Leave for UI (Not Pre-Deploy)

These are runtime adjustments best made after testing:

| Feature | Why Defer | How to Configure |
|---------|-----------|------------------|
| **Specific Regex Patterns** | May need tuning based on your addon selection and RD blocking evolution | UI → Filters → Regex Patterns (add/remove patterns as RD blocks evolve) |
| **Cached vs. Uncached Strategy** | Depends on your debrid plan limits and network speed preferences | UI → Cached/Uncached tabs (toggle filters) |
| **Sort Order Customization** | Depends on personal preference (quality vs. speed vs. diversity) | UI → Sorting (drag-reorder) |
| **Addon Categories/Organization** | Depends on how many addons you eventually add | UI → Addons → Categorise |
| **Stream Expression Language Edits** | For advanced filtering beyond basic regex; requires testing | UI → Excluded Stream Expressions (code editor) |
| **Seeder/Size Thresholds** | Tuned based on your tolerance for slow/large downloads | UI → Filters → Size/Seeder ranges |
| **Language Preferences** | Highly personal | UI → Filters → Language |

## Configuration Complexity Tiers

**Tier 1 (Minimal, Recommended Start):**
- Set `SECRET_KEY` at deploy time
- Enter RD credentials via UI
- Add Torrentio via custom URL
- Set one exclude regex pattern in UI
- Done (30 min)

**Tier 2 (Balanced):**
- Tier 1 + configure deduplicator, sort order
- Tier 1 + add 2-3 additional source addons (Comet, MediaFusion, etc.)
- Tier 1 + SEL-Sync URL for pattern auto-updates
- Total: 1-2 hours

**Tier 3 (Advanced):**
- All of Tier 2 + custom SEL excluded expressions
- All of Tier 2 + Groups (different addon combos for anime vs. movies)
- All of Tier 2 + custom templates and formatting
- Total: 3-4 hours + ongoing maintenance

For single-user homelab RD filtering, recommend Tier 1-2.

## Sources

- [AIOStreams GitHub](https://github.com/Viren070/AIOStreams) — Official repository, README, wiki
- [AIOStreams Official Documentation](https://docs.aiostreams.viren070.me) — Configuration reference, SEL documentation
- [Viren070's Guides - AIOStreams Setup](https://guides.viren070.me/stremio/addons/aiostreams/setup) — Setup walkthrough, Torrentio integration
- [AIOStreams Configuration (.env.sample)](https://github.com/Viren070/AIOStreams/blob/main/.env.sample) — Environment variable reference
- [Stream Expression Language Documentation](https://github.com/Viren070/AIOStreams/wiki/Stream-Expression-Language) — SEL syntax and functions
- [Stream Expression Language Reference](https://docs.aiostreams.viren070.me/reference/stream-expressions/) — SEL function catalog
- [SEL-Filtering-and-Sorting Repository](https://github.com/Tam-Taro/SEL-Filtering-and-Sorting) — Community templates and examples
- [Stremio Perfect Setup - AIOStreams](https://luckynumb3rs.github.io/stremio-perfect-setup/guide/3-AIOStreams-Setup/) — Configuration Q&A and examples
- [ElfHosted AIOStreams Documentation](https://docs.elfhosted.com/app/aiostreams/) — Managed hosting reference
- [Real-Debrid Users Hit with "Infringing File" Errors](https://troypoint.com/real-debrid-users-hit-with-infringing-file-errors/) — Current RD blocking context
- [Stremio + Real Debrid Guide (2026)](https://corelab.tech/stremio-setup-guide/) — 2026 ecosystem overview

## Confidence Assessment

| Dimension | Level | Notes |
|-----------|-------|-------|
| **Regex Filtering Core** | HIGH | Official docs clear; stable since v2.0 |
| **Torrentio Integration** | HIGH | Multiple sources confirm URL format and manifest handling |
| **Real-Debrid Blocking Patterns** | MEDIUM | Pattern from ElfHosted community; evolves monthly; recommend monitoring RD changelog |
| **SEL Advanced Features** | HIGH | Full documentation available; used in community templates |
| **UI Configuration Steps** | MEDIUM | Official guides exist but can be terse; recommend following Viren070 setup guide directly |
| **Deploy-Time vs. UI-Time Distinction** | HIGH | Official docs clear on environment variable scope |

## Gaps / Validation Needed

1. **RD Blocking Pattern Updates (May 2026 Context):** Pattern provided is from ElfHosted community sources dated ~Feb 2025. Real-Debrid's blocking list evolves; recommend checking ElfHosted changelog and community Discord monthly.

2. **SEL Sync URL Sources:** No official community-maintained URL for RD exclusion patterns found. If you want auto-update, you'd need to either:
   - Host your own pattern file and configure `WHITELISTED_REGEX_PATTERNS_URLS` to fetch from it
   - Manually update pattern in `.env` and redeploy
   - Check Tam-Taro's SEL-Filtering-and-Sorting for best-practice patterns

3. **Torrentio-Enabled Public Instance Availability:** The setup guide references public AIOStreams instances with Torrentio; availability may change. At research time, ElfHosted offers Torrentio-enabled AIOStreams as paid service.

4. **Performance at Scale:** Documentation is for single-user homelab; no data on behavior with 100+ addons or 10K+ concurrent results.
