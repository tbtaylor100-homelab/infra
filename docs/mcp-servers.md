# MCP Servers

MCP servers run as K3s workloads in the `mcp-servers` namespace. All configuration lives in `kubernetes/mcp-servers/`. Changes follow the standard IaC workflow: branch → PR → merge → ArgoCD reconciles.

See [ADR-002](http://192.168.1.50:3000/tbtaylor100/homelab-knowledge/src/branch/main/adr/ADR-002-mcp-servers-on-k3s.md) for why MCP servers run on K3s rather than VM 102.

## Active Servers

| Server | Image | Endpoint | Path |
|--------|-------|----------|------|
| forgejo-mcp | `ronmi/forgejo-mcp:latest` | http://192.168.1.203:8080 | `/mcp` |
| proxmox-mcp | `node:22-alpine` + mcp-proxy | http://192.168.1.201:8080 | `/mcp` |
| atlassian-mcp | `ghcr.io/sooperset/mcp-atlassian:latest` | http://192.168.1.202:8080 | `/sse` |

## Adding a New MCP Server

### Step 1 — Identify the deployment pattern

| If the tool is... | Use this pattern |
|-------------------|-----------------|
| An image with a built-in HTTP/SSE server | **Native SSE** — expose the port, target `/mcp` |
| A JavaScript/TypeScript CLI (stdio only) | **mcp-proxy wrapper** — wrap with `node:alpine` + `npx mcp-proxy`, target `/mcp` |
| A Python / FastMCP-based tool | **FastMCP** — pass `--transport sse --port 8080`, target `/sse` (not `/mcp`) |

The FastMCP `/sse` vs `/mcp` distinction is easy to miss — FastMCP hardcodes `/sse` as its route regardless of what other servers use.

### Step 2 — Create the Kubernetes manifest

Create `kubernetes/mcp-servers/<name>.yaml` with a `Deployment` and `Service`. Use an existing manifest as a reference for the pattern you need:

- Native SSE → copy `forgejo-mcp.yaml`
- mcp-proxy wrapper → copy `proxmox-mcp.yaml`
- FastMCP → copy `atlassian-mcp.yaml`

Set `spec.type: LoadBalancer` on the Service — MetalLB assigns an IP from the `192.168.1.200–250` pool automatically.

### Step 3 — Add credentials

Credentials are never in the manifest. They go in K8s secrets, created via Ansible:

1. Add secret variables to `ansible/inventory/group_vars/all/secrets.yml` (gitignored — see `secrets.yml.example`)
2. Add a `kubectl create secret generic` task to `ansible/roles/mcp-servers/tasks/main.yml`
3. Reference the secret in the manifest via `secretKeyRef`

Non-sensitive config (URLs, hostnames) goes in the existing `mcp-servers-config` ConfigMap in `kubernetes/mcp-servers/namespace.yaml`.

### Step 4 — Register in Claude Code (Mac)

Once deployed:

```bash
claude mcp add --transport http <name> http://192.168.1.2XX:8080/<path>
```

Use `/mcp` for Native SSE and mcp-proxy patterns. Use `/sse` for FastMCP.

### Step 5 — Open a PR

ArgoCD picks up the new manifest automatically on merge to `main`. No manual `kubectl apply` needed.
