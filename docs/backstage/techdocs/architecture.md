# System Architecture

The environment is architected into two logical layers: **Infrastructure Core** (Platform Primitives) and **Application Workloads** (Service Layer).

## High-Level Architecture

![High-Level Cluster Architecture](../images/high-lvl-cluster-architecture.svg)

## Architecture Layers

### Infrastructure Core

The foundation layer provides essential platform primitives that all workloads depend on:

| Component | Purpose | Namespace |
|-----------|---------|-----------|
| **K3s** | Lightweight Kubernetes runtime | System |
| **ArgoCD** | GitOps continuous delivery | `argocd` |
| **Cert-Manager** | TLS certificate automation | `cert-manager` |
| **External Secrets** | Secrets synchronization | `external-secrets` |
| **MetalLB** | Bare-metal load balancer | `metallb-system` |
| **Envoy Gateway** | Ingress controller | `envoy-gateway-system` |
| **Longhorn** | Distributed block storage | `longhorn-system` |

### Application Workloads

User-facing services and applications:

| Service | Type | Description |
|---------|------|-------------|
| **Ghost** | CMS | Personal blog platform |
| **Backstage** | Portal | Developer documentation portal |
| **Portfolio** | Website | Personal portfolio site |

## Service Catalog

### User-Facing Applications
*   **[Ghost](https://ghost.jeremymr.dev/):** My personal blog platform. Engineered with a **MariaDB** backend and **Longhorn** for persistent volume management.
*   **Obsidian Vault Sync:** A **CouchDB** NoSQL cluster configured for cross-device synchronization of my Obsidian knowledge base.

### Infrastructure Services
*   **Garage S3:** Self-hosted, distributed S3 storage. Acts as the primary backup target for Longhorn snapshots and the long-term storage backend for Loki logs.
*   **External Secrets (ESO):** Decouples secret management from Git. ESO dynamically pulls credentials from an encrypted provider and injects them as native K8s secrets at runtime.
*   **Identity Management:** **Authentik** serves as the cluster's OIDC provider, enforcing unified SSO across internal administrative dashboards.

## Security Architecture

### Identity & Access Management

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│   User      │────▶│  Authentik  │────▶│  Target     │
│   Request   │     │  (OIDC)     │     │  Service    │
└─────────────┘     └─────────────┘     └─────────────┘
                          │
                          ▼
                    ┌─────────────┐
                    │  Validate   │
                    │  Token      │
                    └─────────────┘
```

### Certificate Management

- **Cluster Issuer**: Let's Encrypt via DNS-01 challenge (Cloudflare)
- **Automatic TLS**: Ingress resources automatically provisioned with valid certificates
- **Wildcard Support**: `*.jeremymr.dev` for internal services

### Secrets Management

- **External Secrets Operator**: Syncs secrets from Doppler
- **ClusterSecretStore**: Central authentication to secrets provider
- **ExternalSecret CRDs**: Declarative secret references in Git