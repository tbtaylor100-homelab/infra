---
phase: 2
slug: kubernetes-manifests
status: draft
nyquist_compliant: true
wave_0_complete: false
created: 2026-05-12
---

# Phase 2 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | kubectl + curl (infra verification) |
| **Config file** | none — cluster verification via kubectl |
| **Quick run command** | `kubectl get all -n aiostreams` |
| **Full suite command** | `kubectl get all -n aiostreams && kubectl describe externalsecret -n aiostreams aiostreams-secret && curl -s http://192.168.1.205:3000/api/v1/status` |
| **Estimated runtime** | ~10 seconds |

---

## Sampling Rate

- **After every task commit:** Run `kubectl get all -n aiostreams`
- **After every plan wave:** Run full suite command above
- **Before `/gsd-verify-work`:** Full suite must be green (all resources Ready, ESO synced, health check returns HTTP 200)
- **Max feedback latency:** 30 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| namespace | 01 | 1 | K8S-01 | — | Namespace isolation | kubectl | `kubectl get namespace aiostreams` | ✅ | ⬜ pending |
| configmap | 01 | 1 | K8S-04 | — | No secrets in ConfigMap | kubectl | `kubectl get configmap -n aiostreams aiostreams-config -o yaml` | ✅ | ⬜ pending |
| externalsecret | 01 | 1 | K8S-02 | T-2-01 | Secrets injected via ESO, not plaintext in git | kubectl | `kubectl get externalsecret -n aiostreams aiostreams-secret && kubectl get secret -n aiostreams aiostreams-secret` | ✅ | ⬜ pending |
| deployment+pvc+svc | 01 | 1 | K8S-03, K8S-05, K8S-06 | T-2-02 | No credentials in env, envFrom from secret only | kubectl | `kubectl get deployment -n aiostreams aiostreams -o wide` | ✅ | ⬜ pending |
| argocd-app | 01 | 2 | K8S-01 | — | GitOps sync active | kubectl | `kubectl get application -n argocd aiostreams` | ✅ | ⬜ pending |
| health-check | 02 | 2 | K8S-03 | — | Health endpoint reachable from LAN | curl | `curl -s http://192.168.1.205:3000/api/v1/status` | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

No automated test framework installation needed — all verification is via kubectl and curl against the live cluster. Both tools are assumed present in the execution environment.

*Existing infrastructure covers all phase requirements.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| ESO secret sync from OpenBao | K8S-02 | Requires Phase 1 OpenBao secrets to exist | `kubectl describe externalsecret -n aiostreams aiostreams-secret` — status.conditions must show `Ready: True` |
| PVC bound with 10Gi | K8S-05 | Requires k3s local-path provisioner response | `kubectl get pvc -n aiostreams aiostreams-sqlite` — STATUS must be Bound |
| LAN health check from non-control-plane device | K8S-06 | Success criteria requires non-control-plane origin | Run `curl -s http://192.168.1.205:3000/api/v1/status` from a LAN device (laptop, phone, etc.) — not from k3s control plane node |
| ArgoCD App synced and healthy | K8S-01 | Requires ArgoCD UI observation | Check ArgoCD Applications UI — `aiostreams` app must show Synced + Healthy (no OutOfSync) |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
