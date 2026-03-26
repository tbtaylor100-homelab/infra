variable "vm_id" {
  description = "Proxmox VM ID (must be unique across the cluster)"
  type        = number
}

variable "name" {
  description = "VM hostname"
  type        = string
}

variable "node" {
  description = "Proxmox node to provision on"
  type        = string
  default     = "pve"
}

variable "cores" {
  description = "Number of vCPUs"
  type        = number
  default     = 2
}

variable "memory_mb" {
  description = "RAM in megabytes"
  type        = number
  default     = 2048
}

variable "disk_size_gb" {
  description = "Root disk size in gigabytes"
  type        = number
  default     = 20
}

variable "storage_pool" {
  description = "Proxmox storage pool for the VM disk"
  type        = string
  default     = "Intel660P"
}

variable "cloud_image_path" {
  description = "Path to the cloud image on the Proxmox node (used as clone source)"
  type        = string
  default     = "local:iso/noble-server-cloudimg-amd64.img"
}

variable "ip_address" {
  description = "Static IP address with CIDR prefix (e.g. 192.168.1.50/24)"
  type        = string
}

variable "gateway" {
  description = "Default gateway IP"
  type        = string
  default     = "192.168.1.1"
}

variable "dns_server" {
  description = "DNS server IP"
  type        = string
  default     = "1.1.1.1"
}

variable "ssh_public_key" {
  description = "SSH public key to authorise on the VM"
  type        = string
}

variable "vm_password" {
  description = "Password for the default user — enables password SSH auth from any LAN device"
  type        = string
  default     = null
  sensitive   = true
}

variable "tags" {
  description = "List of Proxmox tags to apply to the VM"
  type        = list(string)
  default     = []
}
