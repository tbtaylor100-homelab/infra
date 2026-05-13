# Phase 2: Kubernetes Manifests - Context

**Gathered:** 2026-05-12
**Status:** Ready for planning

<domain>
## Phase Boundary

Create the Kubernetes manifests that bring AIOStreams to a running, LAN-accessible state: Namespace, ConfigMap (regex patterns), ExternalSecret (ESO → OpenBao secret sync), Deployment (pod spec + probes + env), PVC (SQLite persistence), Service (MetalLB LoadBalancer), and ArgoCD Application CR. This phase ends when the ArgoCD app is synced, the pod passes health checks at `/api/v1/status`, and any LAN device can reach `http://192.168.1.205:3000`.

</domain>

<decisions>
## Implementation Decisions

### File organization
- **D-01:** `kubernetes/aiostreams/` uses 4 split files matching the mcp-servers convention: `namespace.yaml`, `external-secret.yaml`, `configmap.yaml`, `deployment.yaml` (Deployment + PVC + Service together in one file since they're tightly coupled). ArgoCD `path: kubernetes/aiostreams` picks up all files automatically.

### BASE_URL and MetalLB IP
- **D-02:** AIOStreams is pinned to `192.168.1.205` via `metallb.universe.tf/loadBalancerIPs` annotation on the Service. This is the next sequential free IP in the homelab-pool (`192.168.1.200–220`). Assigned IPs: .200 ArgoCD, .201 proxmox-mcp, .202 atlassian-mcp, .203 forgejo-mcp, .204 Grafana, .210 OpenBao.
- **D-03:** `BASE_URL=http://192.168.1.205:3000` baked into the Deployment env vars. No two-phase deploy needed.

### Regex pattern storage and content
- **D-04:** `WHITELISTED_REGEX_PATTERNS` lives in a ConfigMap (`configmap.yaml`) rather than inline in the Deployment env. Reason: the regex pattern is expected to evolve quarterly as RD's block list changes (per REQUIREMENTS.md RES-01) — a ConfigMap isolates the evolving value from the Deployment spec. The Deployment uses `envFrom` to inject all ConfigMap keys as env vars.
- **D-05:** Initial regex value: `["/(WEB-DL|AMZN|DSNP|YTS|RARBG|EZTV)/i"]` — targets the known RD-blocked release tags from the phase research. Researcher should confirm against ElfHosted's current documentation before writing the ConfigMap. Format is a JSON array of JavaScript regex strings (PITFALLS.md warns against comma-separated or newline-separated plain text — must be JSON array).

### Secret mounting
- **D-06:** ESO ExternalSecret pulls `SECRET_KEY` and `FORCED_SERVICE_CREDENTIALS` from `ClusterSecretStore/openbao` at `secret/aiostreams/production` and writes them as a native k8s Secret named `aiostreams-secret` in the `aiostreams` namespace. This sets the `<app>-secret` naming convention for future ESO-managed workloads.
- **D-07:** The Deployment uses `envFrom: secretRef: name: aiostreams-secret` to inject all fields as env vars. Since field names in OpenBao match env var names exactly (D-03 from Phase 1 CONTEXT.md), no per-field remapping is needed. This is the first ExternalSecret workload in the cluster — no prior ESO pattern exists to follow.

### Claude's Discretion
- ExternalSecret `refreshInterval`: choose appropriate value (e.g., `1h` is common); `SECRET_KEY` is immutable so it won't change, but the interval must be set.
- Exact `WHITELISTED_REGEX_PATTERNS` JSON escaping in YAML (use block scalar or single quotes to avoid escaping nightmares — see PITFALLS.md).
- Resource limits on the Deployment: REQUIREMENTS.md specifies 100m/500m CPU, 128Mi/256Mi RAM — use as-is.
- `ADDON_NAME` and other optional env vars: researcher should verify `.env.sample` and omit anything not strictly required.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### ArgoCD Application pattern
- `argocd/apps/mcp-servers.yaml` — canonical ArgoCD Application CR; use this as the template (CreateNamespace=true, prune: true, selfHeal: true, targetRevision: main)

### ESO + OpenBao integration
- `kubernetes/external-secrets/cluster-secret-store.yaml` — ClusterSecretStore config; name is `openbao`, Kubernetes auth, role `eso-reader`; this is what the ExternalSecret's `storeRef` must reference
- `kubernetes/external-secrets/eso-policy.hcl` — policy file committed in Phase 1; confirms `secret/data/aiostreams/*` read access is granted
- `homelab-knowledge/adr/ADR-011-external-secrets-operator.md` — decision to use ESO; ClusterSecretStore/ExternalSecret pattern
- `homelab-knowledge/adr/ADR-005-openbao-secrets-manager.md` — OpenBao setup and KV v2 path conventions

### Existing workload patterns (for file layout reference)
- `kubernetes/mcp-servers/namespace.yaml` — namespace resource example
- `kubernetes/mcp-servers/proxmox-mcp.yaml` — Deployment + LoadBalancer Service in one file; shows MetalLB pattern WITHOUT ip pinning annotation (aiostreams adds the annotation)

### Phase 1 context (decisions that carry forward)
- `.planning/phases/01-secrets-and-prerequisites/01-CONTEXT.md` — D-03: field names SECRET_KEY and FORCED_SERVICE_CREDENTIALS match env var names; runbook location and format decisions

### AIOStreams documentation (researcher must verify)
- AIOStreams `.env.sample` on GitHub (Viren070/AIOStreams) — verify FORCED_SERVICE_CREDENTIALS format, optional env vars, WHITELISTED_REGEX_PATTERNS format
- ElfHosted AIOStreams documentation — fetch exact WHITELISTED_REGEX_PATTERNS value used on their hosted instance as baseline for D-05

### Research artifacts
- `.planning/research/PITFALLS.md` — WHITELISTED_REGEX_PATTERNS must be JSON array, not comma/newline-separated; FORCED_SERVICE_CREDENTIALS format warnings
- `.planning/research/STACK.md` — verified env var names, PVC spec, resource limits
- `.planning/research/ARCHITECTURE.md` — reference architecture (note: its ConfigMap example uses wrong newline format — follow PITFALLS.md JSON array format instead)

</canonical_refs>

<code_context>
## Existing Code Insights

### Established Patterns
- **ArgoCD Application:** All apps use identical pattern — `CreateNamespace=true`, `prune: true`, `selfHeal: true`, `targetRevision: main`, `repoURL: http://forgejo.local:3000/root/infra.git`. Planner should copy `argocd/apps/mcp-servers.yaml` verbatim and change only `name`, `path`, and `namespace`.
- **LoadBalancer Service:** All intranet services use `type: LoadBalancer` with MetalLB. mcp-servers Services use no IP annotation (auto-assigned). AIOStreams adds `metallb.universe.tf/loadBalancerIPs: 192.168.1.205` to pin the IP.
- **Namespace:** Split as a separate `namespace.yaml` (mcp-servers pattern). `CreateNamespace=true` in ArgoCD also creates it, but an explicit manifest is present for clarity — follow the same convention.
- **No ExternalSecret exists yet:** This is the FIRST workload using ESO. The researcher must look up the ExternalSecret CRD structure (`external-secrets.io/v1beta1`) and verify against the `cluster-secret-store.yaml` to write a correct `storeRef`.

### Integration Points
- `ClusterSecretStore/openbao` — the ExternalSecret must reference this store by name. Namespace-scoped (`aiostreams`) ExternalSecret pointing at a ClusterSecretStore does not need a namespace qualifier in the `storeRef`.
- ArgoCD watches `http://forgejo.local:3000/root/infra.git` on `main` — once the ArgoCD Application CR is committed and pushed to main, it syncs automatically (prune + selfHeal).

</code_context>

<specifics>
## Specific Ideas

- The AIOStreams image is `ghcr.io/viren070/aiostreams:v2.29.5` — pin the exact version, do not use `latest`.
- Health probes: both liveness and readiness on `GET /api/v1/status` (port 3000) — per REQUIREMENTS.md K8S-03.
- PVC name from REQUIREMENTS.md K8S-05: `aiostreams-sqlite` (not `aiostreams-data`), mounted at `/app/data`, 10Gi, `local-path`.
- ConfigMap should also include `REGEX_FILTER_ACCESS: "all"` and `PORT: "3000"` so those non-secret plain-text config values don't clutter the Deployment env section.
- `FORCED_SERVICE_CREDENTIALS` format stored in OpenBao is the full value `realdebrid.apiKey=<key>` — the ExternalSecret writes this verbatim as the env var value, AIOStreams reads it directly.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 2-kubernetes-manifests*
*Context gathered: 2026-05-12*
