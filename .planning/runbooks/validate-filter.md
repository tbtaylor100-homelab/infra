# Filter Validation Procedure

This is a one-time validation confirming the AIOStreams regex exclusion filter is active and blocking WEB-DL, YTS, AMZN, DSNP, RARBG, and EZTV-tagged streams from appearing in Stremio search results. Complete this procedure **after** following `setup-aiostreams.md` — the filter must be activated first.

## Prerequisites

- AIOStreams running and reachable at `http://192.168.1.205:3000`
- Torrentio addon installed and visible in AIOStreams **Addons → Installed** tab
- Regex exclusion filter activated in AIOStreams **Filters → Regex Patterns**
- AIOStreams added as a Stremio addon source at `http://192.168.1.205:3000/manifest.json`
- See [homelab-knowledge/runbooks/setup-aiostreams.md](../homelab-knowledge/runbooks/setup-aiostreams.md) for all of the above

## Procedure

### Step 1: Open Stremio and search for known WEB-DL content

Use these specific search terms — all have widely available WEB-DL, AMZN, and YTS-tagged versions in Torrentio:

- TV shows: **"Breaking Bad"**, **"The Office"**, **"Game of Thrones"**
- Movies: **"Oppenheimer"**, **"Dune Part Two"**, **"The Godfather"**

Search for any of the above in Stremio. Wait for results to load (may take 5–10 seconds as AIOStreams queries Torrentio).

### Step 2: Inspect stream results

For each search result that shows streams, review the stream source labels:

- **Expected (filter active):** No stream titles or labels containing `WEB-DL`, `AMZN`, `DSNP`, `YTS`, `RARBG`, or `EZTV`
- **Not expected (indicates filter is not working):** entries like "1080p WEB-DL", "AMZN WEB-DL", "YTS.MX", "EZTV"

### Step 3: Optional baseline comparison

To confirm AIOStreams is the source of filtering (and not a Torrentio outage or empty cache):

1. Temporarily add vanilla Torrentio directly in Stremio: `https://torrentio.strem.fun/manifest.json`
2. Search for the same content — WEB-DL/YTS entries **should appear** in vanilla Torrentio results (they are not filtered)
3. Remove vanilla Torrentio after verification

### Step 4: Cache-clear if results appear stale

If Stremio still shows WEB-DL results after confirming the filter is active in AIOStreams:

1. In Stremio: **Settings → Addons**
2. Remove the AIOStreams source
3. Re-add it: `http://192.168.1.205:3000/manifest.json`

This forces Stremio to refresh addon state and re-fetch filtered results from AIOStreams.

## Pass Criteria

All of the following must be true:

- At least one search returns results (pod is healthy, addon connectivity OK)
- No stream titles or labels contain: `WEB-DL`, `AMZN`, `DSNP`, `YTS`, `RARBG`, `EZTV`
- Vanilla Torrentio comparison (Step 3) shows those tags ARE present in unfiltered results, confirming AIOStreams is the source of filtering

## Fail Criteria and Remediation

| Symptom | Likely cause | Remediation |
|---------|-------------|-------------|
| Zero results from any search | Pod not responding or addon connectivity failure | Check `kubectl logs -n aiostreams deployment/aiostreams --tail=30`; verify `curl -s http://192.168.1.205:3000/api/v1/status` returns 200 |
| WEB-DL entries still appear in results | Filter not activated or regex pattern not applied | Navigate AIOStreams **Filters → Regex Patterns**; confirm toggle is enabled; verify env: `kubectl exec -n aiostreams deployment/aiostreams -- env \| grep WHITELISTED` |
| Real-Debrid streams return "error" or "unavailable" | RD API key invalid or ESO sync failed | Check Services menu in AIOStreams UI; run `kubectl get externalsecret -n aiostreams aiostreams-secret` for sync status |
| Stremio shows stale results after filter was activated | Stremio addon cache | Remove and re-add AIOStreams addon source (Step 4) |
