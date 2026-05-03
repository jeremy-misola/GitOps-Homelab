# GitOps-Homelab

[![Kubernetes](https://img.shields.io/badge/kubernetes-%23326ce5.svg?style=flat&logo=kubernetes&logoColor=white)](https://kubernetes.io)
[![ArgoCD](https://img.shields.io/badge/Argo%20CD-EF7B4D?style=flat&logo=argo-cd&logoColor=white)](https://argoproj.github.io/cd/)
[![Envoy Gateway](https://img.shields.io/badge/Envoy%20Gateway-E64A19?style=flat&logo=envoyproxy&logoColor=white)](https://gateway.envoyproxy.io/)

This repository is the single source of truth for my homelab platform. It provisions the underlying virtual machines on Proxmox, bootstraps K3s with Ansible, and continuously reconciles platform services and workloads through ArgoCD.

The current architecture is split across two Kubernetes environments:

- `prod-k3s`: the primary highly available cluster for shared platform services and user-facing apps
- `dev-k3s`: a smaller development cluster for testing changes before they graduate to production

---

## Architecture

The homelab now has three layers: infrastructure provisioning, Kubernetes platform services, and application workloads.

### Provisioning Layer

| Area | Implementation | Notes |
| :--- | :--- | :--- |
| Virtualization | Proxmox VE | Hosts every control plane and worker VM |
| Infrastructure as Code | Terraform | Creates the `prod` and `dev` VM fleets and generates per-cluster inventories |
| Bootstrap | Ansible | Installs K3s, disables bundled networking/storage defaults, and bootstraps ArgoCD |
| Secrets for Provisioning | Doppler | Supplies Proxmox API credentials and K3s bootstrap tokens |

### Kubernetes Platform

| Domain | Components |
| :--- | :--- |
| Runtime | K3s |
| GitOps | ArgoCD |
| Networking | MetalLB, Envoy Gateway, cloudflared |
| PKI | cert-manager with Cloudflare DNS-01 |
| Identity | Authentik |
| Secrets | External Secrets Operator |
| Storage | Longhorn, Garage S3 |
| Data Platforms | CloudNativePG |
| Platform Automation | Crossplane with Terraform, Helm, and Kubernetes providers |
| Observability | kube-prometheus-stack, Grafana, Loki, Tempo, OpenTelemetry, blackbox-exporter |

### Cluster Topology

| Cluster | Topology | Purpose |
| :--- | :--- | :--- |
| `prod-k3s` | 3 control planes, 3 workers | Production platform services, ingress, storage, observability, and user-facing apps |
| `dev-k3s` | 1 control plane, 2 workers | Lower-cost validation environment for platform and app changes |

```mermaid
flowchart TB
    User["Users / Admin"]
    Git["GitHub Repo<br/>GitOps-Homelab"]
    Doppler["Doppler"]
    CF["Cloudflare DNS / Tunnel"]
    LE["Let's Encrypt"]
    Proxmox["Proxmox VE"]
    TF["Terraform"]
    Ansible["Ansible"]

    subgraph Provisioning["Provisioning Layer"]
        Proxmox --> TF
        Doppler --> TF
        TF -->|"Create VMs + inventories"| Ansible
        Ansible -->|"Install K3s + ArgoCD"| ProdCluster
        Ansible -->|"Install K3s + ArgoCD"| DevCluster
    end

    Git -->|"Root app + sync chain"| ArgoCD
    Git -->|"Dev root app + sync chain"| DevArgo

    subgraph ProdCluster["Production K3s Cluster"]
        ArgoCD["ArgoCD"]
        ESO["External Secrets"]
        Crossplane["Crossplane"]
        CertManager["cert-manager"]
        MetalLB["MetalLB"]
        Envoy["Envoy Gateway"]
        Authentik["Authentik"]
        Longhorn["Longhorn"]
        Garage["Garage S3"]
        CloudNativePG["CloudNativePG"]
        Otel["OpenTelemetry<br/>Operator + Collector"]
        LGTM["Prometheus / Grafana / Loki / Tempo"]
        Cloudflared["cloudflared"]

        subgraph Apps["Workloads"]
            Backstage["Backstage"]
            AdGuard["AdGuard"]
            KubeSandbox["KubeSandbox"]
            Portfolio["Portfolio"]
        end
    end

    subgraph DevCluster["Development K3s Cluster"]
        DevArgo["ArgoCD"]
        DevApps["Dev workloads"]
    end

    User --> CF
    CF --> Cloudflared
    User --> Envoy
    Doppler --> ESO
    LE -->|"ACME DNS-01 via Cloudflare"| CertManager
    CertManager -->|"Wildcard TLS certs"| Envoy
    MetalLB -->|"LoadBalancer IPs"| Envoy
    Authentik -->|"OIDC / SSO"| Backstage
    Authentik -->|"OIDC / SSO"| LGTM
    Crossplane -->|"Terraform workspaces + providers"| Authentik
    Crossplane -->|"Buckets / credentials"| Garage
    Longhorn -->|"Persistent volumes"| Authentik
    Longhorn -->|"Persistent volumes"| Garage
    Longhorn -->|"Persistent volumes"| LGTM
    CloudNativePG -->|"Operator-managed Postgres"| Backstage
    Envoy -->|"HTTPRoute"| Apps
    Apps -->|"Telemetry"| Otel
    Otel -->|"Logs / traces"| LGTM
```

---

## GitOps Lifecycle

The cluster is reconciled through a Helm-generated ArgoCD sync chain.

1. `bootstrap/root-app-dev.yaml` and `bootstrap/root-app-prod.yaml` are the manual entry points for each cluster.
2. `operators-helm/values/values-dev.yaml` and `operators-helm/values/values-prd.yaml` define the environment, target Git revision, enabled operators, and sync waves.
3. `operators-helm/templates/` renders ArgoCD `Application` resources for Helm releases plus any pre-install and post-install manifests.
4. `operators-helm/operators/` contains per-service chart values and the raw Kubernetes resources that surround each chart.
5. ArgoCD continuously self-heals the cluster back to the state declared in Git.

This ordering keeps foundational services such as secrets, storage, ingress, and certificates ahead of dependent workloads.

---

## Workloads

### Platform Services

- `Authentik` provides OIDC and shared SSO for internal dashboards.
- `Backstage` acts as the internal developer portal and service catalog.
- `AdGuard Home` provides network-level DNS filtering.
- `Garage S3` backs object storage use cases such as Loki retention and backup targets.
- `CloudNativePG` supplies operator-managed PostgreSQL for stateful services.

### Applications

- `KubeSandbox` is a multi-service workload deployed as separate frontend and backend charts.
- `Portfolio` is a custom application deployed with its own service, route, secrets, and database resources.
- `dev-k3s` is reserved for validating platform and application changes before promoting them to `prod-k3s`.

---

## Observability

The platform uses an OpenTelemetry-first LGTM stack:

- `kube-prometheus-stack` scrapes Kubernetes, cluster services, and blackbox probes.
- `OpenTelemetry Operator` provides Java auto-instrumentation for supported workloads.
- `OpenTelemetry Collector` receives and enriches telemetry before forwarding it downstream.
- `Loki` stores logs with Garage S3 as the object storage backend.
- `Tempo` stores traces for distributed request visibility.
- `Grafana` ties metrics, logs, and traces together for correlation and troubleshooting.

Telemetry flow is straightforward: workloads and platform services emit signals to the collector, Prometheus scrapes metrics directly, and Grafana becomes the shared entry point for debugging across the stack.

---

## Repository Map

| Path | Purpose |
| :--- | :--- |
| `bootstrap/` | Root ArgoCD applications per environment |
| `operators-helm/` | Helm-templated ArgoCD application factory and operator definitions |
| `provisioning/terraform/` | Proxmox VM provisioning and generated inventories |
| `provisioning/ansible/` | K3s bootstrap automation |
| `docs/backstage/catalog/` | Backstage software catalog entities |
| `docs/code/` | Mermaid source diagrams |
| `scripts/` | Utility playbooks and maintenance helpers |

---

*Maintained by [Jeremy Misola](https://github.com/jeremy-misola).*
