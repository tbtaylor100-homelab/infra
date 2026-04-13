variable "proxmox_endpoint" {
  description = "Proxmox API endpoint (e.g. https://192.168.1.X:8006/)"
  type        = string
}

variable "proxmox_api_token" {
  description = "Proxmox API token in the format 'user@realm!token-id=secret'"
  type        = string
  sensitive   = true
}

variable "ssh_public_key" {
  description = "SSH public key to authorise on k3s-control-01"
  type        = string
}

variable "ssh_private_key" {
  description = "SSH private key content used by bpg/proxmox for disk operations"
  type        = string
  sensitive   = true
}
