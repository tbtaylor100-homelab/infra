# ESO reader policy — grants External Secrets Operator read access to KV v2 secrets
# Policy name: eso-policy (bound to the eso-reader Kubernetes auth role)
# Applied via: bao policy write -address=http://192.168.1.210:8200 eso-policy kubernetes/external-secrets/eso-policy.hcl
# WARNING: bao policy write is a full replacement — both paths must be present or the missing path loses access.

path "secret/data/homelab/ci" {
  capabilities = ["read"]
}

path "secret/data/aiostreams/*" {
  capabilities = ["read"]
}
