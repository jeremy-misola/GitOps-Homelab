# GitOps Homelab Documentation

Welcome to the **GitOps Homelab** documentation portal. This serves as the single source of truth for infrastructure documentation, architecture decisions, and operational runbooks.

## Overview

This repository serves as the **Single Source of Truth** for my homelab. Developed over the last eight months as part of my transition into DevOps.

The cluster is managed through **Declarative GitOps** and the **App of Apps pattern**, ensuring the entire infrastructure—from networking to end-user services—is reproducible, version-controlled, and self-healing.

## Technical Stack

| Layer | Component | Implementation |
| :--- | :--- | :--- |
| **Orchestration** | Runtime | **K3s** (Lightweight Kubernetes) |
| **GitOps** | CD Engine | **ArgoCD** |
| **Networking** | Service Mesh & L2 | **Istio**, **Envoy Gateway**, **MetalLB** |
| **Storage** | Block & S3 | **Longhorn** (CSI), **Garage S3** |
| **Security** | Identity & Secrets | **Authentik** (OIDC), **External Secrets (ESO)**, **Cert-Manager** |
| **Infrastructure as Code** | Resource Management | **Crossplane** (with provider-terraform) |
| **Observability** | LGTM Stack | **Loki**, **Grafana**, **Tempo**, **Prometheus** |

## Documentation Sections

### Architecture
- [Architecture Overview](architecture.md) - High-level system architecture
- [Observability Stack](observability.md) - LGTM stack and telemetry pipeline
- [GitOps Sync Chain](sync-chain.md) - ArgoCD application lifecycle

### Infrastructure
- [Crossplane](infrastructure/crossplane.md) - Infrastructure as Code via Crossplane
- [Terraform Provisioning](infrastructure/terraform.md) - Proxmox VM provisioning

### Bootstrap
- [ArgoCD Bootstrap](bootstrap/argocd.md) - Cluster initialization and GitOps bootstrap

### Catalog Reference
- [Components](catalog/components.md) - All registered components
- [Systems](catalog/systems.md) - System organization
- [APIs](catalog/apis.md) - API definitions
- [Resources](catalog/resources.md) - Infrastructure resources

## Quick Links

| Service | URL | Description |
|---------|-----|-------------|
| ArgoCD | https://argocd.jeremymr.dev | GitOps dashboard |
| Grafana | https://grafana.jeremymr.dev | Observability dashboard |
| Authentik | https://auth.jeremymr.dev | Identity provider |
| Ghost Blog | https://ghost.jeremymr.dev | Personal blog |
| Backstage | https://devdocs.jeremymr.dev | Developer portal |

---

*Maintained by [Jeremy Misola](http://github.com/jeremy-misola) — DevOps Engineer & Platform Enthusiast.*