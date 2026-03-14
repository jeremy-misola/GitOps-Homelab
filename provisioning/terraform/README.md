# Terraform Proxmox VM Provisioning

This Terraform configuration provisions 6 VMs on Proxmox for a Kubernetes cluster:
- 3 Control Plane nodes (8GB RAM, 100GB disk each)
- 3 Worker nodes (32GB RAM, 200GB disk each)

## Prerequisites

- [Terraform](https://www.terraform.io/downloads) >= 1.0.0
- [Doppler CLI](https://docs.doppler.com/docs/installing-the-cli) installed and configured
- Proxmox VE with the `ubuntu-2404-template` template (tag 900)
- Proxmox API token with appropriate permissions

## Doppler Setup

This configuration uses Doppler to manage sensitive credentials. Add the following secrets to your Doppler project:

| Secret Name | Description | Example |
|-------------|-------------|---------|
| `PM_API_TOKEN_ID` | Proxmox API token ID | `root@pam!terraform` |
| `PM_API_TOKEN_SECRET` | Proxmox API token secret | `xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx` |
| `TF_VAR_k3s_token` | K3s cluster token for node authentication | Generate with `openssl rand -base64 64` |

### Setting up Doppler secrets

```bash
# Login to Doppler
doppler login

# Create a project (if you don't have one)
doppler projects create homelab

# Setup the project in this directory
doppler setup
# Select your project and config (e.g., homelab > prd)

# Add secrets (you'll be prompted for values)
doppler secrets set PM_API_TOKEN_ID
doppler secrets set PM_API_TOKEN_SECRET
doppler secrets set TF_VAR_k3s_token

# Or set with values directly
doppler secrets set PM_API_TOKEN_ID="root@pam!terraform"
doppler secrets set PM_API_TOKEN_SECRET="your-secret-here"
doppler secrets set TF_VAR_k3s_token="$(openssl rand -base64 64)"
```

**Alternative:** Use the Doppler dashboard at https://dashboard.doppler.com to add secrets via the web UI.

## Usage

```bash
# Initialize Terraform
terraform init

# Preview changes (secrets injected from Doppler)
doppler run -- terraform plan

# Apply configuration (automatically runs Ansible after VMs are ready)
doppler run -- terraform apply

# Destroy resources
doppler run -- terraform destroy
```

### Automated Ansible Integration

After Terraform provisions the VMs, it automatically:
1. Waits 60 seconds for VMs to fully boot
2. Installs required Ansible collections
3. Runs the K3s Ansible playbook to configure the cluster

The Ansible playbook (`../k3s-ansible/playbooks/site.yml`) is triggered via a `null_resource` with `local-exec` provisioner. The playbook will only run when:
- VMs are first created
- Control plane or worker IPs change
- K3s version changes

To re-run Ansible without recreating VMs:
```bash
cd ../k3s-ansible
ansible-playbook playbooks/site.yml -i inventory.yml
```

Or taint the null_resource to force re-run:
```bash
terraform taint null_resource.run_ansible
doppler run -- terraform apply
```

## Configuration

Non-sensitive configuration is stored in `terraform.tfvars`. Key settings:

| Variable | Default | Description |
|----------|---------|-------------|
| `pm_api_url` | `https://192.168.0.230:8006/api2/json` | Proxmox API URL |
| `target_node` | `pve` | Proxmox node name |
| `template_name` | `ubuntu-2404-template` | VM template to clone |
| `storage_pool` | `local-lvm` | Storage pool for disks |
| `network_bridge` | `vmbr0` | Network bridge |
| `gateway` | `192.168.0.1` | Network gateway |

### VM Resource Configuration

| Node Type | Count | IPs | Memory | Disk | CPUs |
|-----------|-------|-----|--------|------|------|
| Control Plane | 3 | 192.168.0.210-212 | 8GB | 100GB | 2 |
| Worker | 3 | 192.168.0.213-215 | 32GB | 200GB | 4 |

## Creating a Proxmox API Token

1. Login to Proxmox web UI
2. Go to **Datacenter** → **Permissions** → **API Tokens**
3. Click **Add** and select a user (e.g., `root@pam`)
4. Enter a Token ID (e.g., `terraform`)
5. Uncheck "Privilege Separation" if you want full permissions
6. Copy the Token ID and Secret (shown only once!)

## Outputs

After applying, Terraform will output:
- `control_plane_vms` - Details of control plane VMs
- `worker_vms` - Details of worker VMs
- `ansible_inventory` - Ansible-compatible inventory
- `all_vm_ips` - List of all VM IP addresses

## File Structure

```
terraform/
├── main.tf              # Provider and VM resources
├── variables.tf         # Input variables
├── outputs.tf           # Output definitions
├── terraform.tfvars     # Non-sensitive variable values
├── terraform.tfvars.example # Example configuration
└── README.md            # This file