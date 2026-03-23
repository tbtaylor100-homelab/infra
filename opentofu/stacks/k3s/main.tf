terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.73"
    }
  }

  # State is stored locally on the operator Mac and gitignored.
  # Migrate to MinIO once K3s is running (MAHHAUS-50).
  backend "local" {
    path = "terraform.tfstate"
  }
}

provider "proxmox" {
  endpoint  = var.proxmox_endpoint
  api_token = var.proxmox_api_token
  insecure  = true # self-signed cert on pve

  # SSH is required by bpg/proxmox for disk operations (e.g. cloning cloud images).
  # Run: ssh-copy-id -i ~/.ssh/id_ed25519.pub root@192.168.1.12
  ssh {
    agent       = true
    username    = "root"
    private_key = file("~/.ssh/id_ed25519")
  }
}

module "k3s_vm" {
  source = "../../modules/proxmox-vm"

  vm_id        = 110
  name         = "k3s-control-01"
  cores        = 4
  memory_mb    = 8192
  disk_size_gb = 60
  storage_pool = "Intel660P"
  ip_address   = "192.168.1.50/24"
  gateway      = "192.168.1.1"
  dns_server   = "1.1.1.1"

  ssh_public_key = var.ssh_public_key

  tags = ["k3s", "managed-by-opentofu"]
}

output "vm_id" {
  value = module.k3s_vm.vm_id
}

output "ip_address" {
  value = module.k3s_vm.ip_address
}

output "mac_address" {
  description = "Use this MAC address for the TP-Link router reservation (MAHHAUS-61)"
  value       = module.k3s_vm.mac_address
}
