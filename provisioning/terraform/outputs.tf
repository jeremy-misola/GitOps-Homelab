output "cluster_vms" {
  description = "Details of all VMs grouped by cluster"
  value = {
    for cluster_name, cluster in var.clusters : cluster_name => {
      control_plane = {
        for index, ip in cluster.control_plane.ips : "${cluster_name}-cp-${index + 1}" => {
          id        = proxmox_vm_qemu.node["${cluster_name}-cp-${index + 1}"].id
          name      = proxmox_vm_qemu.node["${cluster_name}-cp-${index + 1}"].name
          ip        = ip
          memory    = proxmox_vm_qemu.node["${cluster_name}-cp-${index + 1}"].memory
          cores     = proxmox_vm_qemu.node["${cluster_name}-cp-${index + 1}"].cores
          disk_size = cluster.control_plane.disk_size
          status    = proxmox_vm_qemu.node["${cluster_name}-cp-${index + 1}"].vm_state
        }
      }
      worker = {
        for index, ip in cluster.worker.ips : "${cluster_name}-worker-${index + 1}" => {
          id        = proxmox_vm_qemu.node["${cluster_name}-worker-${index + 1}"].id
          name      = proxmox_vm_qemu.node["${cluster_name}-worker-${index + 1}"].name
          ip        = ip
          memory    = proxmox_vm_qemu.node["${cluster_name}-worker-${index + 1}"].memory
          cores     = proxmox_vm_qemu.node["${cluster_name}-worker-${index + 1}"].cores
          disk_size = cluster.worker.disk_size
          status    = proxmox_vm_qemu.node["${cluster_name}-worker-${index + 1}"].vm_state
        }
      }
    }
  }
}

output "ansible_inventory_files" {
  description = "Generated Ansible inventory files for each cluster"
  value = {
    for cluster_name, cluster in local.cluster_configs : cluster_name => local_file.ansible_inventory[cluster_name].filename
  }
}

output "all_vm_ips" {
  description = "List of all VM IP addresses across every cluster"
  value = flatten([
    for cluster in values(var.clusters) : concat(cluster.control_plane.ips, cluster.worker.ips)
  ])
}
