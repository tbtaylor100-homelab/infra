# CI test: verifies OpenBao secret injection via AppRole (MAH-69)
terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.73"
    }
  }

  backend "s3" {
    endpoint = "http://192.168.1.132:9000"
    bucket   = "opentofu-state"
    key      = "k3s/terraform.tfstate"
    region   = "us-east-1" # MinIO ignores region but the field is required

    skip_credentials_validation = true
    skip_metadata_api_check     = true
    skip_region_validation      = true
    use_path_style              = true
  }
  # Credentials: export AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY before running tofu
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
    private_key = var.ssh_private_key
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
  ip_address   = "192.168.1.60/24"
  gateway      = "192.168.1.1"
  dns_server   = "1.1.1.1"

  ssh_public_key = var.ssh_public_key

  tags = ["k3s", "managed-by-opentofu"]
}

output "vm_id" {
  value = module.k3s_vm.vm_id
}

output "ip_address" {
  description = "k3s-control-01 static IP (192.168.1.60 — separate from Forgejo at .50)"
  value       = module.k3s_vm.ip_address
}

output "mac_address" {
  description = "Use this MAC address for the TP-Link router reservation (MAHHAUS-61)"
  value       = module.k3s_vm.mac_address
}
