terraform {
  required_version = ">= 1.0.0"

  required_providers {
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
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

locals {
  cluster_tokens = {
    prod = var.prod_k3s_token
    dev  = var.dev_k3s_token
  }

  cluster_configs = {
    for cluster_name, cluster in var.clusters : cluster_name => {
      cluster_context = "${cluster_name}-k3s"
      inventory_file  = "${path.module}/../inventory-${cluster_name}.yml"
      control_plane   = cluster.control_plane
      worker          = cluster.worker
    }
  }

  control_plane_nodes = merge([
    for cluster_name, cluster in local.cluster_configs : {
      for index, ip in cluster.control_plane.ips : "${cluster_name}-cp-${index + 1}" => {
        cluster   = cluster_name
        role      = "control-plane"
        vm_name   = "${cluster_name}-cp-${index + 1}"
        ip        = ip
        memory    = cluster.control_plane.memory
        cores     = cluster.control_plane.cores
        disk_size = cluster.control_plane.disk_size
      }
    }
  ]...)

  worker_nodes = merge([
    for cluster_name, cluster in local.cluster_configs : {
      for index, ip in cluster.worker.ips : "${cluster_name}-worker-${index + 1}" => {
        cluster   = cluster_name
        role      = "worker"
        vm_name   = "${cluster_name}-worker-${index + 1}"
        ip        = ip
        memory    = cluster.worker.memory
        cores     = cluster.worker.cores
        disk_size = cluster.worker.disk_size
      }
    }
  ]...)

  all_nodes = merge(local.control_plane_nodes, local.worker_nodes)
}

resource "proxmox_vm_qemu" "node" {
  for_each = local.all_nodes

  name        = each.value.vm_name
  target_node = var.target_node

  clone      = var.template_name
  full_clone = true

  agent              = 1
  start_at_node_boot = true
  vm_state           = "running"
  os_type            = "cloud-init"
  scsihw             = "virtio-scsi-single"
  boot               = "order=scsi0"

  memory = each.value.memory

  cpu {
    type  = "host"
    cores = each.value.cores
  }

  disks {
    scsi {
      scsi0 {
        disk {
          size     = each.value.disk_size
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

  ciuser     = var.ci_user
  sshkeys    = var.ssh_public_keys
  nameserver = var.nameserver

  ipconfig0 = "ip=${each.value.ip}/24,gw=${var.gateway}"

  tags = join(",", ["kubernetes", each.value.cluster, each.value.role])

  lifecycle {
    ignore_changes = [
      network,
    ]
  }
}

resource "local_file" "ansible_inventory" {
  for_each = local.cluster_configs

  filename = each.value.inventory_file
  content = templatefile("${path.module}/inventory.tftpl", {
    ansible_user      = var.ci_user
    control_plane_ips = each.value.control_plane.ips
    worker_ips        = each.value.worker.ips
    k3s_version       = var.k3s_version
    cluster_context   = each.value.cluster_context
    extra_server_args = var.extra_server_args
    extra_agent_args  = var.extra_agent_args
  })
}

resource "null_resource" "run_ansible" {
  for_each = local.cluster_configs

  depends_on = [
    proxmox_vm_qemu.node,
    local_file.ansible_inventory,
  ]

  triggers = {
    cluster_name      = each.key
    inventory_sha     = sha256(local_file.ansible_inventory[each.key].content)
    k3s_version       = var.k3s_version
    control_plane_ips = join(",", each.value.control_plane.ips)
    worker_ips        = join(",", each.value.worker.ips)
  }

  provisioner "local-exec" {
    command = <<-EOT
      set -e
      echo "=== Waiting for ${each.key} VMs to be ready ==="
      sleep 60

      echo "=== Installing Ansible dependencies ==="
      cd "${path.module}/../k3s-ansible"
      ansible-galaxy collection install -r collections/requirements.yml

      echo "=== Running Ansible playbook for ${each.key} cluster ==="
      ansible-playbook playbooks/site.yml -i "${local_file.ansible_inventory[each.key].filename}" -e "token=$${K3S_TOKEN}"

      echo "=== ${each.key} K3s cluster provisioning complete! ==="

      # Use absolute path for virtual environment to avoid issues with relative paths after cd
      VENV_PATH="${abspath(path.module)}/venv-${each.key}"
      
      # Create virtual environment for local Ansible tasks
      python3.13 -m venv "$VENV_PATH"
      "$VENV_PATH/bin/pip" install kubernetes

      echo "=== Installing ArgoCD for ${each.key} cluster ==="
      cd "${path.module}/../ansible"
      ansible-galaxy collection install -r requirements.yml

      # Force use of the virtual environment python for local tasks
      ansible-playbook playbooks/install_argocd.yml \
        -i localhost, \
        -e "ansible_python_interpreter=$VENV_PATH/bin/python" \
        -e "kube_context=${each.value.cluster_context}" \
        -e "cluster_name=${each.key}"
    EOT

    environment = {
      K3S_TOKEN = local.cluster_tokens[each.key]
    }
  }
}
