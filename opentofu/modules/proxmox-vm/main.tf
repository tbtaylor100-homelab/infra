terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.73"
    }
  }
}

# Adopt the cloud image if already present, or download it if not.
# overwrite_unmanaged = true allows OpenTofu to take ownership of a file
# that was downloaded outside of OpenTofu (e.g. manually in Phase 0).
resource "proxmox_virtual_environment_download_file" "cloud_image" {
  content_type        = "iso"
  datastore_id        = "local"
  node_name           = var.node
  url                 = "https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img"
  file_name           = "noble-server-cloudimg-amd64.img"
  overwrite           = false
  overwrite_unmanaged = true
}

resource "proxmox_virtual_environment_vm" "vm" {
  vm_id     = var.vm_id
  name      = var.name
  node_name = var.node
  tags      = var.tags

  cpu {
    cores = var.cores
    type  = "x86-64-v2-AES"
  }

  memory {
    dedicated = var.memory_mb
  }

  agent {
    enabled = true
  }

  # Boot disk — cloned from the cloud image
  # file_format = "raw" is required for LVM storage (Intel660P); LVM does not support qcow2
  disk {
    datastore_id = var.storage_pool
    file_id      = proxmox_virtual_environment_download_file.cloud_image.id
    interface    = "virtio0"
    size         = var.disk_size_gb
    file_format  = "raw"
    discard      = "on"
    iothread     = true
  }

  network_device {
    bridge = "vmbr0"
    model  = "virtio"
  }

  boot_order = ["virtio0"]

  operating_system {
    type = "l26"
  }

  # Cloud-init configuration
  initialization {
    ip_config {
      ipv4 {
        address = var.ip_address
        gateway = var.gateway
      }
    }

    dns {
      servers = [var.dns_server]
    }

    user_account {
      username = "ubuntu"
      keys     = [var.ssh_public_key]
      password = var.vm_password
    }
  }

  lifecycle {
    ignore_changes = [
      # Ignore disk size changes after initial creation (managed by guest OS)
      disk,
    ]
  }

  depends_on = [
    proxmox_virtual_environment_download_file.cloud_image,
  ]
}
