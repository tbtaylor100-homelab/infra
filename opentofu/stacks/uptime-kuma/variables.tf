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
  description = "SSH public key to authorise on uptime-kuma-01 (used by Ansible)"
  type        = string
}

variable "vm_password" {
  description = "Password for the ubuntu user — allows SSH from any LAN device"
  type        = string
  sensitive   = true
}
