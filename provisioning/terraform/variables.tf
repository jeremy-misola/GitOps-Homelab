# Proxmox Connection Variables
# Credentials are read from environment variables set by Doppler:
#   PM_API_TOKEN_ID     - Proxmox API token ID
#   PM_API_TOKEN_SECRET - Proxmox API token secret
#   K3S_TOKEN           - K3s cluster token (mapped to TF_VAR_k3s_token)
#
# Run: doppler run -- sh -c 'TF_VAR_k3s_token=$K3S_TOKEN terraform apply'

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

# Control Plane Variables
variable "control_plane_cores" {
  description = "Number of CPU cores for control plane nodes"
  type        = number
  default     = 2
}

variable "control_plane_memory" {
  description = "Memory in MB for control plane nodes"
  type        = number
  default     = 8192
}

variable "control_plane_disk_size" {
  description = "Disk size for control plane nodes (e.g., '100G')"
  type        = string
  default     = "100G"
}

variable "control_plane_ips" {
  description = "List of IP addresses for control plane nodes"
  type        = list(string)
  default     = [
    "192.168.0.210",
    "192.168.0.211",
    "192.168.0.212"
  ]
}

# Worker Variables
variable "worker_cores" {
  description = "Number of CPU cores for worker nodes"
  type        = number
  default     = 4
}

variable "worker_memory" {
  description = "Memory in MB for worker nodes"
  type        = number
  default     = 32768
}

variable "worker_disk_size" {
  description = "Disk size for worker nodes (e.g., '200G')"
  type        = string
  default     = "200G"
}

variable "worker_ips" {
  description = "List of IP addresses for worker nodes"
  type        = list(string)
  default     = [
    "192.168.0.213",
    "192.168.0.214",
    "192.168.0.215"
  ]
}

# K3s Cluster Variables
variable "k3s_token" {
  description = "K3s cluster token for node authentication (injected via TF_VAR_k3s_token from Doppler K3S_TOKEN)"
  type        = string
  sensitive   = true
}