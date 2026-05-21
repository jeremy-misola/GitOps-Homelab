# Proxmox Connection Variables
# Credentials are read from environment variables set by Doppler:
#   PM_API_TOKEN_ID     - Proxmox API token ID
#   PM_API_TOKEN_SECRET - Proxmox API token secret
#   PROD_K3S_TOKEN      - Production K3s cluster token (mapped to TF_VAR_prod_k3s_token)
#   DEV_K3S_TOKEN       - Development K3s cluster token (mapped to TF_VAR_dev_k3s_token)
#
# Run:
# doppler run -- sh -c '\''TF_VAR_prod_k3s_token=$PROD_K3S_TOKEN TF_VAR_dev_k3s_token=$DEV_K3S_TOKEN terraform apply'\''

variable "pm_api_url" {
  description = "The URL of the Proxmox API"
  type        = string
}

variable "pm_tls_insecure" {
  description = "Skip TLS verification for Proxmox API"
  type        = bool
  default     = true
}

variable "target_node" {
  description = "The Proxmox node to create VMs on"
  type        = string
}

# Template and Storage Variables
variable "template_name" {
  description = "Name of the template to clone"
  type        = string
  default     = "ubuntu-2404-template"
}

variable "storage_pool" {
  description = "The storage pool for VM disks"
  type        = string
  default     = "local-lvm"
}

# Network Variables
variable "network_bridge" {
  description = "The network bridge to use"
  type        = string
  default     = "vmbr0"
}

variable "gateway" {
  description = "The network gateway"
  type        = string
  default     = "192.168.0.1"
}

variable "nameserver" {
  description = "The DNS nameserver for VMs"
  type        = string
  default     = "192.168.0.1"
}

# Cloud-Init Variables
variable "ci_user" {
  description = "The cloud-init user"
  type        = string
  default     = "jurassicjey"
}

variable "ssh_public_keys" {
  description = "SSH public keys for VM access"
  type        = string
}

# K3s Configuration
variable "k3s_version" {
  description = "K3s version to install on both clusters"
  type        = string
  default     = "v1.36.1+k3s1"
}

variable "extra_server_args" {
  description = "Extra K3s server arguments applied to every cluster"
  type        = string
  default     = "--disable=traefik --disable=servicelb --disable=local-storage"
}

variable "extra_agent_args" {
  description = "Extra K3s agent arguments applied to every cluster"
  type        = string
  default     = ""
}

# Cluster Topology
variable "clusters" {
  description = "Cluster definitions for each environment"
  type = map(object({
    control_plane = object({
      ips       = list(string)
      cores     = number
      memory    = number
      disk_size = string
    })
    worker = object({
      ips       = list(string)
      cores     = number
      memory    = number
      disk_size = string
    })
  }))

  default = {
    prod = {
      control_plane = {
        ips       = ["192.168.0.210", "192.168.0.211", "192.168.0.212"]
        cores     = 2
        memory    = 6144
        disk_size = "100G"
      }
      worker = {
        ips       = ["192.168.0.213", "192.168.0.214", "192.168.0.215"]
        cores     = 6
        memory    = 16384
        disk_size = "200G"
      }
    }
    dev = {
      control_plane = {
        ips       = ["192.168.0.220"]
        cores     = 2
        memory    = 6144
        disk_size = "100G"
      }
      worker = {
        ips       = ["192.168.0.221", "192.168.0.222"]
        cores     = 4
        memory    = 20480
        disk_size = "200G"
      }
    }
  }

  validation {
    condition = alltrue([
      for cluster in values(var.clusters) : length(cluster.control_plane.ips) > 0 && length(cluster.control_plane.ips) % 2 == 1
    ])
    error_message = "Each cluster must define an odd number of control plane IPs and include at least one control plane node."
  }
}

# K3s Cluster Tokens
variable "prod_k3s_token" {
  description = "Production K3s cluster token (injected via TF_VAR_prod_k3s_token from Doppler PROD_K3S_TOKEN)"
  type        = string
  sensitive   = true
}

variable "dev_k3s_token" {
  description = "Development K3s cluster token (injected via TF_VAR_dev_k3s_token from Doppler DEV_K3S_TOKEN)"
  type        = string
  sensitive   = true
}
