# Phase 2: Kubernetes Manifests - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-05-12
**Phase:** 02-kubernetes-manifests
**Areas discussed:** File layout, BASE_URL + IP pinning, Regex pattern content, Secret mounting strategy

---

## File layout

| Option | Description | Selected |
|--------|-------------|----------|
| Split files | 3–4 files: namespace.yaml, external-secret.yaml, configmap.yaml, deployment.yaml. Matches mcp-servers convention. | ✓ |
| Monolithic file | All resources in one deployment.yaml with --- separators. Matches forgejo-runner pattern. | |
| You decide | Claude picks layout based on codebase. | |

**User's choice:** Split files
**Notes:** User initially asked for more context before deciding. After explanation, chose split files matching the mcp-servers pattern. File organization naturally expanded to 4 files once ConfigMap decision was made in the Regex area.

---

## BASE_URL + IP pinning

| Option | Description | Selected |
|--------|-------------|----------|
| Pin a MetalLB IP | Use `metallb.universe.tf/loadBalancerIPs` annotation. BASE_URL pre-set in manifest. One deploy. | ✓ |
| Two-phase deploy | Apply without BASE_URL, get assigned IP, patch and re-apply. | |
| Leave BASE_URL empty | Deploy without BASE_URL, configure post-deploy. | |

**User's choice:** Pin 192.168.1.205 (next sequential free IP in pool)
**Notes:** User asked to look up the MetalLB pool from the cluster. Pool is 192.168.1.200–220 with 15 IPs available. Sequential assignments: .200 ArgoCD, .201 proxmox-mcp, .202 atlassian-mcp, .203 forgejo-mcp, .204 Grafana, .210 OpenBao. User confirmed .205.

---

## Regex pattern content

### Storage location

| Option | Description | Selected |
|--------|-------------|----------|
| ConfigMap | Isolated in configmap.yaml. Pattern updates don't touch Deployment spec. | ✓ |
| Inline in Deployment env | Baked into deployment.yaml env section. Simpler file count. | |

**User's choice:** ConfigMap
**Notes:** User initially asked "What is the purpose of configmap?" — explained that a ConfigMap is a Kubernetes object for plain (non-secret) config key/value pairs, decoupled from the Deployment spec. User chose ConfigMap after understanding.

### Pattern content

| Option | Description | Selected |
|--------|-------------|----------|
| Research-documented pattern | `["/(WEB-DL|AMZN|DSNP|YTS|RARBG|EZTV)/i"]` from phase research docs. | ✓ |
| Researcher fetches ElfHosted's exact pattern | Researcher looks up current ElfHosted WHITELISTED_REGEX_PATTERNS from docs. | |
| Start empty | Deploy with no patterns, configure via UI post-deploy. | |

**User's choice:** Research-documented pattern (researcher confirms against ElfHosted docs before writing)
**Notes:** User initially selected "ElfHosted's known pattern" in the area selection. Research files don't have ElfHosted's exact pattern — STACK.md has the documented approximation. User accepted the research-documented pattern with researcher confirmation step.

---

## Secret mounting strategy

| Option | Description | Selected |
|--------|-------------|----------|
| envFrom: secretRef | One envFrom declaration injects all secret fields. Clean for 2-field secret with matching field names. | ✓ |
| Individual valueFrom per field | Explicit env var block per field. More verbose. | |

**User's choice:** envFrom: secretRef referencing `aiostreams-secret`
**Notes:** User initially described the mental model as "ESO adds them as a Kubernetes secret, so they should be available via env variables" — confirmed that envFrom is the mechanism that makes this happen. User asked for more context on naming before choosing `aiostreams-secret`. User noted this is the first ESO workload so no prior naming pattern exists — `aiostreams-secret` sets the `<app>-secret` convention.

---

## Claude's Discretion

- ExternalSecret `refreshInterval` value (1h is a sensible default)
- YAML escaping strategy for WHITELISTED_REGEX_PATTERNS JSON array (block scalar or single-quoted)
- Optional env vars to include/omit (researcher verifies against .env.sample)

## Deferred Ideas

None — discussion stayed within phase 2 scope.
