terraform {
  required_version = ">= 1.0.0"
  
  required_providers {
    proxmox = {
      source  = "telmate/proxmox"
      version = "3.0.2-rc07"
    }
  }
}

provider "proxmox" {
  pm_api_url      = var.pm_api_url
  pm_tls_insecure = var.pm_tls_insecure
  
  # Credentials are read from environment variables set by Doppler:
  # PM_API_TOKEN_ID     - Proxmox API token ID
  # PM_API_TOKEN_SECRET - Proxmox API token secret
}

# Control Plane VMs
resource "proxmox_vm_qemu" "control_plane" {
  count = 3

  name        = "k8s-cp-${count.index + 1}"
  target_node = var.target_node
  
  clone       = var.template_name
  full_clone  = true
  
  agent              = 1
  start_at_node_boot = true
  vm_state           = "running"
  os_type            = "cloud-init"
  scsihw             = "virtio-scsi-single"
  boot               = "order=scsi0"

  memory = var.control_plane_memory

  cpu {
    type  = "host"
    cores = var.control_plane_cores
  }

  disks {
    scsi {
      scsi0 {
        disk {
          size     = var.control_plane_disk_size
          storage  = var.storage_pool
          iothread = true
        }
      }
    }
    ide {
      ide3 {
        cloudinit {
          storage = var.storage_pool
        }
      }
    }
  }

  network {
    id     = 0
    model  = "virtio"
    bridge = var.network_bridge
  }

  # Cloud-Init configuration
  ciuser     = var.ci_user
  sshkeys    = var.ssh_public_keys
  nameserver = var.nameserver
  
  ipconfig0 = "ip=${var.control_plane_ips[count.index]}/24,gw=${var.gateway}"

  tags = "kubernetes,control-plane"

  lifecycle {
    ignore_changes = [
      network,
    ]
  }
}

# Worker VMs
resource "proxmox_vm_qemu" "worker" {
  count = 3

  name        = "k8s-worker-${count.index + 1}"
  target_node = var.target_node
  
  clone       = var.template_name
  full_clone  = true
  
  agent              = 1
  start_at_node_boot = true
  vm_state           = "running"
  os_type            = "cloud-init"
  scsihw             = "virtio-scsi-single"
  boot               = "order=scsi0"

  memory = var.worker_memory

  cpu {
    type  = "host"
    cores = var.worker_cores
  }

  disks {
    scsi {
      scsi0 {
        disk {
          size     = var.worker_disk_size
          storage  = var.storage_pool
          iothread = true
        }
      }
    }
    ide {
      ide3 {
        cloudinit {
          storage = var.storage_pool
        }
      }
    }
  }

  network {
    id     = 0
    model  = "virtio"
    bridge = var.network_bridge
  }

  # Cloud-Init configuration
  ciuser     = var.ci_user
  sshkeys    = var.ssh_public_keys
  nameserver = var.nameserver
  
  ipconfig0 = "ip=${var.worker_ips[count.index]}/24,gw=${var.gateway}"

  tags = "kubernetes,worker"

  lifecycle {
    ignore_changes = [
      network,
    ]
  }
}

# Run Ansible playbook after VMs are provisioned
resource "null_resource" "run_ansible" {
  # Only run after all VMs are created
  depends_on = [
    proxmox_vm_qemu.control_plane,
    proxmox_vm_qemu.worker
  ]

  # Trigger on VM IP changes
  triggers = {
    control_plane_ips = join(",", var.control_plane_ips)
    worker_ips        = join(",", var.worker_ips)
    k3s_version       = "v1.31.12+k3s1"
  }

  provisioner "local-exec" {
    command = <<-EOT
      echo "=== Waiting for VMs to be ready ==="
      sleep 60
      
      echo "=== Installing Ansible dependencies ==="
      cd "${path.module}/../k3s-ansible"
      ansible-galaxy collection install -r collections/requirements.yml
      
      echo "=== Running Ansible playbook ==="
      ansible-playbook playbooks/site.yml -i ../inventory.yml -e "token=$${K3S_TOKEN}"
      
      echo "=== K3s cluster provisioning complete! ==="
    EOT
    
    environment = {
      K3S_TOKEN = var.k3s_token
    }
  }
}
