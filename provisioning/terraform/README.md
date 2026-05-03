# Terraform Proxmox VM Provisioning

This Terraform configuration provisions two K3s clusters on Proxmox:
- Production: 3 control plane nodes (6GB RAM, 2 vCPU) and 3 worker nodes (16GB RAM, 6 vCPU)
- Development: 1 control plane node (6GB RAM, 2 vCPU) and 2 worker nodes (20GB RAM, 4 vCPU)

Terraform also generates a dedicated Ansible inventory for each cluster and runs the K3s playbook separately for `prod` and `dev`.

## Prerequisites

- [Terraform](https://www.terraform.io/downloads) >= 1.0.0
- [Doppler CLI](https://docs.doppler.com/docs/installing-the-cli) installed and configured
- Proxmox VE with the `ubuntu-2404-template` template available
- Proxmox API token with appropriate permissions
- `kubectl` installed on the control machine if you want kubeconfig contexts merged automatically

## Doppler Setup

This configuration uses Doppler to manage sensitive credentials. Add the following secrets to your Doppler project:

| Secret Name | Description | Example |
|-------------|-------------|---------|
| `PM_API_TOKEN_ID` | Proxmox API token ID | `root@pam!terraform` |
| `PM_API_TOKEN_SECRET` | Proxmox API token secret | `xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx` |
| `PROD_K3S_TOKEN` | K3s token for the production cluster | `openssl rand -base64 64` |
| `DEV_K3S_TOKEN` | K3s token for the development cluster | `openssl rand -base64 64` |

### Setting up Doppler secrets

```bash
# Login to Doppler
doppler login

# Create a project (if you don't have one)
doppler projects create homelab

# Setup the project in this directory
doppler setup
# Select your project and config (for example homelab > prd)

# Add secrets
doppler secrets set PM_API_TOKEN_ID
doppler secrets set PM_API_TOKEN_SECRET
doppler secrets set PROD_K3S_TOKEN="$(openssl rand -base64 64)"
doppler secrets set DEV_K3S_TOKEN="$(openssl rand -base64 64)"
```

## Usage

```bash
cd provisioning/terraform

# Initialize Terraform
terraform init

# Preview changes
doppler run -- sh -c 'TF_VAR_prod_k3s_token=$PROD_K3S_TOKEN TF_VAR_dev_k3s_token=$DEV_K3S_TOKEN terraform plan'

# Apply configuration
# This provisions all VMs, generates provisioning/inventory-prod.yml and
# provisioning/inventory-dev.yml, and runs Ansible once per cluster.
doppler run -- sh -c 'TF_VAR_prod_k3s_token=$PROD_K3S_TOKEN TF_VAR_dev_k3s_token=$DEV_K3S_TOKEN terraform apply'

# Destroy resources
doppler run -- sh -c 'TF_VAR_prod_k3s_token=$PROD_K3S_TOKEN TF_VAR_dev_k3s_token=$DEV_K3S_TOKEN terraform destroy'
```

## What Terraform Does

After applying, Terraform will:
1. Create all `prod` and `dev` VMs from the shared Proxmox template.
2. Generate `provisioning/inventory-prod.yml` and `provisioning/inventory-dev.yml`.
3. Wait for the nodes to boot.
4. Install required Ansible collections.
5. Run `playbooks/site.yml` once for `prod` and once for `dev`.
6. Merge kubeconfig contexts as `prod-k3s` and `dev-k3s` when `kubectl` is available.

## Configuration

Non-sensitive configuration lives in `terraform.tfvars`.

### Shared Settings

| Variable | Default | Description |
|----------|---------|-------------|
| `pm_api_url` | `https://192.168.0.230:8006/api2/json` | Proxmox API URL |
| `target_node` | `proxmox` | Proxmox node name |
| `template_name` | `ubuntu-2404-template` | VM template to clone |
| `storage_pool` | `local-lvm` | Storage pool for disks |
| `network_bridge` | `vmbr0` | Network bridge |
| `gateway` | `192.168.0.1` | Network gateway |
| `k3s_version` | `v1.31.12+k3s1` | K3s version for both clusters |

### Cluster Topology

| Cluster | Node Type | Count | Memory | Disk | vCPU |
|---------|-----------|-------|--------|------|------|
| `prod` | Control Plane | 3 | 6GB | 100GB | 2 |
| `prod` | Worker | 3 | 16GB | 200GB | 6 |
| `dev` | Control Plane | 1 | 6GB | 100GB | 2 |
| `dev` | Worker | 2 | 20GB | 200GB | 4 |

Default IP layout:
- `prod` control plane: `192.168.0.210-212`
- `prod` workers: `192.168.0.213-215`
- `dev` control plane: `192.168.0.220`
- `dev` workers: `192.168.0.221-222`

## Re-running Ansible

```bash
cd provisioning/k3s-ansible
ansible-playbook playbooks/site.yml -i ../inventory-prod.yml -e "token=$PROD_K3S_TOKEN"
ansible-playbook playbooks/site.yml -i ../inventory-dev.yml -e "token=$DEV_K3S_TOKEN"
```

To force Terraform to re-run Ansible for one cluster:

```bash
cd provisioning/terraform
terraform taint 'null_resource.run_ansible["prod"]'
terraform taint 'null_resource.run_ansible["dev"]'
```

## Outputs

After applying, Terraform will output:
- `cluster_vms` - VM details grouped by `prod` and `dev`
- `ansible_inventory_files` - Generated inventory file paths for each cluster
- `all_vm_ips` - Every VM IP across both clusters
