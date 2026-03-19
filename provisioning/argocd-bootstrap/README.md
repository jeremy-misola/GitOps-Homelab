# ArgoCD Bootstrap Playbook

Automated ArgoCD installation and GitOps bootstrap for k3s clusters.

## Prerequisites

- k3s cluster installed via k3s-ansible (or manually)
- Ansible 8.0+ (ansible-core 2.15+) on control node
- SSH access to the first server node
- Root or sudo access on the target node

## Quick Start

### 1. Install k3s cluster (if not already done)

```bash
cd ../k3s-ansible
ansible-playbook playbooks/site.yml -i inventory.yml
```

### 2. Install ArgoCD

Using the k3s-ansible inventory:

```bash
ansible-playbook install-argocd.yaml -i ../k3s-ansible/inventory.yml
```

Or using a custom inventory file:

```bash
ansible-playbook install-argocd.yaml -i your-inventory.ini
```

### 3. Access ArgoCD

```bash
# Port-forward to access locally
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Access at https://localhost:8080
# Username: admin
# Password: (displayed in playbook output)
```

## Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `argocd_version` | `v2.14.13` | ArgoCD version to install |
| `argocd_namespace` | `argocd` | Namespace for ArgoCD |
| `kubeconfig_path` | `/etc/rancher/k3s/k3s.yaml` | Path to kubeconfig on server |
| `bootstrap_app_url` | (GitHub raw URL) | URL to root-app.yaml |
| `skip_bootstrap` | `false` | Skip applying the bootstrap application |
| `doppler_bootstrap_token` | `""` | Doppler service token for fetching ESO token |
| `doppler_eso_token_name` | `ESO_TOKEN` | Name of the ESO token secret in Doppler |

### Overriding Variables

```bash
# Install a different ArgoCD version
ansible-playbook install-argocd.yaml -i inventory.yml -e "argocd_version=v2.13.0"

# Skip bootstrap (only install ArgoCD)
ansible-playbook install-argocd.yaml -i inventory.yml -e "skip_bootstrap=true"

# Use a custom bootstrap URL
ansible-playbook install-argocd.yaml -i inventory.yml -e "bootstrap_app_url=https://your-repo/root-app.yaml"
```

## What This Playbook Does

1. **Waits for k3s** - Ensures the cluster is ready
2. **Creates namespace** - Creates the `argocd` namespace
3. **Installs ArgoCD** - Applies the official ArgoCD manifests
4. **Waits for readiness** - Waits for all ArgoCD components to be healthy
5. **Displays credentials** - Shows the initial admin password
6. **Bootstrap ESO token** - Creates the Doppler token secret for External Secrets Operator
7. **Applies bootstrap** - Applies the `root-app.yaml` to trigger GitOps sync

## External Secrets Operator Bootstrap

The playbook can automatically fetch the ESO token from Doppler and create the required Kubernetes secret. This is needed because the `ClusterSecretStore` requires the `doppler-token-auth-api` secret to authenticate with Doppler.

### Prerequisites

1. Create a Doppler service token with read access to the project containing your ESO token:
   - Go to Doppler → Project → Settings → Service Tokens
   - Create a token with read access

2. Store the ESO token in Doppler:
   - Create a secret named `ESO_TOKEN` (or customize with `doppler_eso_token_name`)
   - The value should be a Doppler service token that External Secrets Operator will use

### Setup Ansible Vault (Recommended)

```bash
# Copy the example vault file
cp vault.yml.example vault.yml

# Edit and add your Doppler bootstrap token
ansible-vault edit vault.yml

# Run the playbook with vault
ansible-playbook install-argocd.yaml -i inventory.yml --ask-vault-pass
```

### Alternative: Pass Token Directly

```bash
# Less secure - token visible in process list
ansible-playbook install-argocd.yaml -i inventory.yml -e "doppler_bootstrap_token=dp.st.xxx"
```

### Skip ESO Bootstrap

If you don't want to bootstrap ESO (or will do it manually):

```bash
# Simply don't provide doppler_bootstrap_token
ansible-playbook install-argocd.yaml -i inventory.yml
```

Or manually create the secret:

```bash
HISTIGNORE='*kubectl*' kubectl create secret generic \
    doppler-token-auth-api \
    --from-literal dopplerToken="dp.st.your-eso-token" \
    -n external-secrets
```

## The Bootstrap Chain

After ArgoCD is installed, the `root-app.yaml` triggers:

```
bootstrap/root-app.yaml
        │
        ▼
categories/infrastructure.yaml (sync-wave: -5)
        │
        ├── cert-manager
        ├── external-secrets
        ├── envoy-gateway
        ├── longhorn
        └── ... (other infrastructure)
        │
        ▼
categories/applications.yaml (sync-wave: 0)
        │
        ├── backstage
        ├── ghost
        └── portfolio
```

## Manual Bootstrap (Alternative)

If you prefer to bootstrap manually:

```bash
# Install ArgoCD without bootstrap
ansible-playbook install-argocd.yaml -i inventory.yml -e "skip_bootstrap=true"

# Apply root-app manually
kubectl apply -f https://raw.githubusercontent.com/jeremy-misola/GitOps-Homelab/develop/bootstrap/root-app.yaml
```

## Troubleshooting

### ArgoCD pods not starting

```bash
# Check pod status
kubectl get pods -n argocd

# Check events
kubectl describe deployment argocd-server -n argocd
```

### Bootstrap not syncing

```bash
# Check application status
kubectl get applications -n argocd

# Check root-app
kubectl describe application root -n argocd
```

### Reset ArgoCD

```bash
# Delete ArgoCD namespace (WARNING: destructive)
kubectl delete namespace argocd

# Re-run the playbook
ansible-playbook install-argocd.yaml -i inventory.yml
```

## Related Files

- `bootstrap/root-app.yaml` - The root application manifest
- `categories/infrastructure.yaml` - Infrastructure ApplicationSet
- `categories/applications.yaml` - Applications ApplicationSet