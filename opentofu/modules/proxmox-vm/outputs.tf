output "vm_id" {
  description = "Proxmox VM ID"
  value       = proxmox_virtual_environment_vm.vm.vm_id
}

output "name" {
  description = "VM hostname"
  value       = proxmox_virtual_environment_vm.vm.name
}

output "ip_address" {
  description = "VM static IP address (with CIDR)"
  value       = var.ip_address
}

output "mac_address" {
  description = "VM MAC address (use for router DHCP reservation)"
  value       = proxmox_virtual_environment_vm.vm.network_device[0].mac_address
}
