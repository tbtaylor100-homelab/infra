terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.73"
    }
  }
}

# Upload the cloud image as a base disk image if not already present
resource "proxmox_virtual_environment_download_file" "cloud_image" {
  content_type = "iso"
  datastore_id = "local"
  node_name    = var.node
  url          = "https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img"
  file_name    = "noble-server-cloudimg-amd64.img"
  overwrite    = false
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
  disk {
    datastore_id = var.storage_pool
    file_id      = proxmox_virtual_environment_download_file.cloud_image.id
    interface    = "virtio0"
    size         = var.disk_size_gb
    discard      = "on"
    iothread     = true
  }

  # Cloud-init drive
  disk {
    datastore_id = var.storage_pool
    interface    = "ide2"
    file_format  = "raw"
    size         = 4
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
    }
  }

  lifecycle {
    ignore_changes = [
      # Ignore disk size changes after initial creation (managed by guest OS)
      disk,
    ]
  }

  depends_on = [proxmox_virtual_environment_download_file.cloud_image]
}
