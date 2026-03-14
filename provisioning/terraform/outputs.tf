# Control Plane Outputs
output "control_plane_vms" {
  description = "Details of the control plane VMs"
  value = {
    for i, vm in proxmox_vm_qemu.control_plane : "k8s-cp-${i + 1}" => {
      id        = vm.id
      name      = vm.name
      ip        = var.control_plane_ips[i]
      memory    = vm.memory
      cores     = vm.cores
      disk_size = var.control_plane_disk_size
      status    = vm.vm_state
    }
  }
}

# Worker Outputs
output "worker_vms" {
  description = "Details of the worker VMs"
  value = {
    for i, vm in proxmox_vm_qemu.worker : "k8s-worker-${i + 1}" => {
      id        = vm.id
      name      = vm.name
      ip        = var.worker_ips[i]
      memory    = vm.memory
      cores     = vm.cores
      disk_size = var.worker_disk_size
      status    = vm.vm_state
    }
  }
}

# Inventory Output (compatible with Ansible)
output "ansible_inventory" {
  description = "Ansible-compatible inventory of all VMs"
  value = <<-EOT
    [all:vars]
    ansible_user=${var.ci_user}

    [master]
    %{for i, ip in var.control_plane_ips~}
    ${ip}
    %{endfor~}

    [worker]
    %{for i, ip in var.worker_ips~}
    ${ip}
    %{endfor~}
  EOT
}

# All VM IPs
output "all_vm_ips" {
  description = "List of all VM IP addresses"
  value = concat(var.control_plane_ips, var.worker_ips)
}