# Homelab v3

A Kubernetes-based homelab infrastructure managed with ArgoCD GitOps principles. This repository contains the configuration for a self-hosted environment running various services for personal use.

## 🏗️ Architecture Overview

This homelab is built on Kubernetes with the following key components:

- **ArgoCD**: GitOps continuous deployment tool for managing applications
- **MetalLB**: Load balancer for bare metal Kubernetes clusters
- **NGINX Ingress**: HTTP/HTTPS traffic routing and SSL termination
- **Tailscale**: Secure networking and VPN access
- **External Secrets Operator**: Secure secret management
- **Prometheus Stack**: Monitoring and alerting infrastructure

## 📋 Services

### Core Infrastructure
- **ArgoCD** (`argocd` namespace): GitOps continuous deployment
- **MetalLB** (`metallb` namespace): Load balancer for bare metal
- **NGINX Ingress** (`ingress-nginx` namespace): HTTP/HTTPS routing
- **External Secrets Operator** (`external-secrets` namespace): Secret management
- **Tailscale Operator** (`tailscale` namespace): Secure networking

### Applications
- **Excalidraw** (`excalidraw` namespace): Collaborative whiteboarding tool
- **Stirling PDF** (`stirling-pdf` namespace): PDF manipulation and conversion
- **CouchDB** (`couchdb` namespace): NoSQL database
- **Immich** (`immich` namespace): Self-hosted photo and video backup

### Monitoring
- **Kube Prometheus Stack** (`monitoring` namespace): Prometheus, Grafana, and AlertManager

## 🚀 Getting Started

### Prerequisites
- Kubernetes cluster (1.20+)
- Helm 3.x
- ArgoCD CLI (optional)

### Initial Setup

1. **Clone the repository**
   ```bash
   git clone https://github.com/jeremy-misola/homelabv2.git
   cd homelabv2
   ```

2. **Install ArgoCD**
   ```bash
   kubectl create namespace argocd
   kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
   ```

3. **Deploy the root application**
   ```bash
   kubectl apply -f apps/templates/root.yaml
   ```

4. **Access ArgoCD UI**
   ```bash
   kubectl port-forward svc/argocd-server -n argocd 8080:443
   ```
   Navigate to `https://localhost:8080` (default credentials: admin/password)

### Configuration

#### MetalLB Configuration
Configure IP pools and L2 advertisement in `yamls/metallb/`:
- `1-ip-pool.yaml`: Define IP address pool
- `2-l2-advertisement.yaml`: Configure L2 advertisement

#### External Secrets
Configure secret stores and external secrets in `yamls/external-secrets/`:
- `secret-store.yaml`: Define secret store configuration
- Service-specific secrets (e.g., `couchdb.yaml`, `tailscale.yaml`)

#### Ingress Configuration
Service-specific ingress configurations in `yamls/`:
- `argocd/argocd-ingess.yaml`
- `excalidraw/excalidraw-ingress.yaml`
- `kube-prometheus/ingress.yaml`
- `stirling-pdf/stirling-pdf-ingress.yaml`

## 📁 Repository Structure

```
homelabv3/
├── apps/                    # ArgoCD application definitions
│   ├── Chart.yaml          # Root Helm chart
│   └── templates/          # Application manifests
├── charts/                 # Custom Helm charts
│   └── argo-cd/           # ArgoCD Helm chart
├── yamls/                 # Additional Kubernetes manifests
│   ├── argocd/           # ArgoCD configurations
│   ├── excalidraw/       # Excalidraw configurations
│   ├── external-secrets/ # Secret management
│   ├── kube-prometheus/  # Monitoring configurations
│   ├── metallb/          # Load balancer configurations
│   └── stirling-pdf/     # Stirling PDF configurations
└── README.md             # This file
```

## 🔧 Management

### Adding New Services
1. Create application manifest in `apps/templates/`
2. Add any additional configurations to `yamls/`
3. Commit and push changes
4. ArgoCD will automatically sync the new application

### Updating Services
1. Modify the application manifest or Helm values
2. Commit and push changes
3. ArgoCD will detect changes and sync automatically

### Monitoring
Access Grafana dashboard through the configured ingress to monitor:
- Cluster health and resource usage
- Application metrics
- Custom dashboards and alerts

## 🔒 Security

- **Tailscale Integration**: Services can be exposed securely through Tailscale
- **External Secrets**: Sensitive data managed through external secret stores
- **RBAC**: Kubernetes role-based access control configured
- **Network Policies**: Implemented where needed for service isolation

## 📊 Monitoring & Observability

The homelab includes comprehensive monitoring with:
- **Prometheus**: Metrics collection and storage
- **Grafana**: Visualization and dashboards
- **AlertManager**: Alert routing and notification
- **Service Discovery**: Automatic discovery of Kubernetes resources

## 🤝 Contributing

This is a personal homelab repository. If you find this useful for your own setup:
1. Fork the repository
2. Customize configurations for your environment
3. Update documentation as needed

## 📝 Notes

- Repository URL references `homelabv2` (legacy naming)
- All applications use automated sync policies for GitOps
- Services are configured with appropriate resource limits and health checks
- Regular backups recommended for persistent data

## 🔗 Useful Links

- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [MetalLB Documentation](https://metallb.universe.tf/)
- [External Secrets Operator](https://external-secrets.io/)
- [Tailscale Kubernetes Operator](https://tailscale.com/kb/1215/kubernetes-operator/)

---

*Last updated: $(date)*