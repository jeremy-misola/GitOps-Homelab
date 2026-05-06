# GitOps-Homelab

A multi-cluster Kubernetes GitOps platform running on Proxmox VMs with K3s, ArgoCD, and a fully declarative operator deployment engine.

This homelab is a sandbox for cloud-native infrastructure — GitOps workflows, multi-cluster operations, declarative deployments, observability, and in-cluster IaC — all running on bare-metal Proxmox VMs. Every component is deployed and managed through ArgoCD's App-of-Apps pattern, with secrets injected at runtime and infrastructure provisioned via Terraform and Ansible.

## Motivation

The goal of this project is to explore and validate production-grade Kubernetes patterns in a self-hosted environment. From multi-cluster topology and Git-driven reconciliation to zero-trust secret management and full-stack observability, each layer is designed to mirror real-world platform engineering practices — while staying entirely self-contained on homelab hardware.

## Architecture at a Glance

- **Multi-cluster** — 2 independent K3s clusters (dev + prod) with environment-specific configuration
- **ArgoCD** — GitOps engine driving an App-of-Apps pattern with sync-wave ordering
- **Terraform + Ansible** — Full-stack IaC from bare-metal Proxmox VMs to running clusters
- **Doppler + External Secrets** — Zero secrets in git, all injected at runtime
- **OpenTelemetry + LGTM** — Unified observability (logs, traces, metrics)
- **Crossplane** — In-cluster infrastructure orchestration

---

## Cluster Topology

| Cluster | Nodes | Control Plane (CPU / RAM / Disk) | Workers (CPU / RAM / Disk) |
|---------|-------|----------------------------------|----------------------------|
| Dev     | 3     | 1 × 2 cores / 6 GB / 100 GB     | 2 × 4 cores / 20 GB / 200 GB |
| Prod    | 6     | 3 × 2 cores / 6 GB / 100 GB     | 3 × 6 cores / 16 GB / 200 GB |

---

## Provisioning Pipeline

VMs are provisioned on Proxmox via Terraform, then K3s is installed using Ansible — all configuration and join tokens are injected from Doppler environment variables at runtime, keeping secrets out of version control. Once the cluster is running, Ansible installs ArgoCD and applies the root Application, which kicks off the full GitOps bootstrap.

```
Proxmox VE → Terraform → Ansible (K3s) → Ansible (ArgoCD) → ArgoCD Root App → App-of-Apps
```

---

## Deployment Engine

The heart of the platform is a custom App-of-Apps Helm chart that generates up to 3 ArgoCD Applications per operator, orchestrated via sync waves:

1. **Pre-requisites** (wave -1) — Namespaces, secrets, CRDs
2. **Helm chart** (wave 0) — The operator itself from upstream repos
3. **Post-resources** (wave +1) — Configuration CRs and runtime resources

All resources use server-side apply with auto-sync, self-healing, and finalizers for clean teardown. Environment-specific values are kept in separate dev and prod files, so the same template generates both clusters' configurations.

---

## Operators & Applications

All operators deployed in sync-wave order across four layers.

### Foundational Layer

| Wave | Operator | Purpose |
|------|----------|---------|
| 10 | **external-secrets** | Syncs secrets from Doppler into Kubernetes |
| 20 | **metallb** | LoadBalancer IP assignment for bare-metal K3s |
| 30 | **cert-manager** | Automated TLS certificates via Let's Encrypt |
| 40 | **longhorn** | Distributed block storage for persistent volumes |
| 50 | **crossplane** | In-cluster infrastructure orchestration |

### Networking & Identity

| Wave | Operator | Purpose |
|------|----------|---------|
| 70 | **garage** | Self-hosted S3-compatible object storage |
| 80 | **envoy-gateway** | Kubernetes Gateway API ingress controller |
| 90 | **authentik** | Identity provider (OIDC/SSO) |
| 100 | **cloudflare** | Cloudflare Tunnel (cloudflared) for external access |

### Observability Stack

| Wave | Operator | Purpose |
|------|----------|---------|
| 110 | **otel-operator** | OpenTelemetry auto-instrumentation |
| 160 | **loki** | Log aggregation |
| 170 | **tempo** | Distributed tracing |
| 180 | **kube-prometheus** | Prometheus + Grafana + AlertManager |
| 190 | **cloudnativepg** | Managed PostgreSQL operator |
| 200 | **otel-collector** | Telemetry collection pipeline |
| 210 | **blackbox-exporter** | External endpoint monitoring |

### Platform Applications

| Wave | Application | Purpose |
|------|-------------|---------|
| 220 | **backstage** | Developer portal |
| 230 | **adguard** | DNS-level ad-blocking |
| 240 | **kubesandbox-backend** | Ephemeral sandbox environments (backend) |
| 250 | **kubesandbox-frontend** | Ephemeral sandbox environments (frontend) |
| 260 | **portfolio** | Personal portfolio website |

---

## Networking & Ingress

Traffic enters the cluster through two paths:

- **Cloudflare Tunnel** (cloudflared DaemonSet) for external DNS-routed traffic
- **Envoy Gateway** with a LoadBalancer IP assigned by MetalLB for direct ingress

cert-manager handles ACME DNS-01 challenges via Cloudflare, issuing wildcard TLS certificates that terminate at the Gateway TLS listener. Authentik provides OIDC/SSO for platform services.

```
User → Cloudflare DNS → Cloudflare Tunnel → cloudflared → Service
User → MetalLB → Envoy Gateway → HTTPRoute → Service
```

---

## Secret Management

Zero secrets in git. Doppler acts as the external source of truth, synced into Kubernetes by the External Secrets Operator at runtime. ArgoCD sync-wave ordering ensures `external-secrets` (wave 10) deploys before any operator that needs secrets.

---

## Observability

The full LGTM stack (Loki, Grafana, Tempo, Prometheus) is deployed with OpenTelemetry auto-instrumentation:

```
Apps → OTel Operator → OTel Collector → Loki / Tempo / Prometheus → Grafana
```

Longhorn provides persistent volumes for Grafana and Loki, while Garage S3 stores Loki and Tempo chunk data.

---

## Crossplane

Crossplane manages infrastructure directly from Kubernetes using provider-helm, provider-kubernetes, and provider-terraform. Composite resources handle ephemeral sandbox environments (KubeSandbox), OIDC application registration in Authentik, S3 bucket provisioning in Garage, and Longhorn backup authentication.

---

## Environment Differences

The dev and prod clusters run nearly identical operator configurations, with a few key differences:

- **Dev** has a single control-plane node (no HA); **prod** has 3 control-plane nodes with HA
- **Dev** uses 2 workers with more RAM (20 GB each); **prod** uses 3 workers with more cores (6 each)
- **Prod** runs 3-way replicated PostgreSQL via CloudNativePG; dev runs a single instance

---

## GitOps Workflow

1. Push changes to the `develop` branch
2. ArgoCD reconciles within 60 seconds
3. The Root Application picks up updated Helm values
4. Sync waves enforce deployment ordering across all operators
5. Self-healing reverts any manual drift back to the git state

---