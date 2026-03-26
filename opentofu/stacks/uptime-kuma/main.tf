terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.73"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.0"
    }
  }

  backend "local" {
    path = "terraform.tfstate"
  }
}

provider "proxmox" {
  endpoint  = var.proxmox_endpoint
  api_token = var.proxmox_api_token
  insecure  = true

  ssh {
    agent       = true
    username    = "root"
    private_key = file("~/.ssh/id_ed25519")
  }
}

locals {
  vm_ip = "192.168.1.61"
}

module "uptime_kuma_vm" {
  source = "../../modules/proxmox-vm"

  vm_id        = 111
  name         = "uptime-kuma-01"
  cores        = 1
  memory_mb    = 2048
  disk_size_gb = 20
  storage_pool = "Intel660P"
  ip_address   = "${local.vm_ip}/24"
  gateway      = "192.168.1.1"
  dns_server   = "192.168.1.1"

  ssh_public_key = var.ssh_public_key
  vm_password    = var.vm_password

  tags = ["monitoring", "managed-by-opentofu"]
}

# Verify SSH is reachable after VM creation — no auth required, just confirms the
# VM booted, got its IP, and sshd is listening. Fails the apply if SSH doesn't
# come up within 4 minutes.
resource "null_resource" "ssh_ready" {
  triggers = {
    vm_id = module.uptime_kuma_vm.vm_id
  }

  depends_on = [module.uptime_kuma_vm]

  provisioner "local-exec" {
    command = <<-EOT
      echo "Waiting for SSH on ${local.vm_ip}..."
      for i in $(seq 1 24); do
        if ssh-keyscan -T 5 ${local.vm_ip} 2>/dev/null | grep -q ssh; then
          echo "SSH is up on ${local.vm_ip}."
          exit 0
        fi
        echo "Attempt $i/24 — retrying in 10s..."
        sleep 10
      done
      echo "ERROR: SSH did not come up on ${local.vm_ip} within 4 minutes."
      exit 1
    EOT
  }
}

output "vm_id" {
  value = module.uptime_kuma_vm.vm_id
}

output "ip_address" {
  value = module.uptime_kuma_vm.ip_address
}

output "mac_address" {
  description = "Use this MAC for the router DHCP reservation"
  value       = module.uptime_kuma_vm.mac_address
}
