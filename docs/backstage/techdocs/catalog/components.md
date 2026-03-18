# Components Reference

This page provides a reference for all registered components in the GitOps Homelab catalog.

## Platform Infrastructure Components

### ArgoCD

| Property | Value |
|----------|-------|
| **Type** | Service |
| **Lifecycle** | Production |
| **Owner** | team-platform |
| **System** | platform-infrastructure |
| **Dashboard** | https://argocd.jeremymr.dev |

GitOps continuous delivery platform for Kubernetes.

### Authentik

| Property | Value |
|----------|-------|
| **Type** | Service |
| **Lifecycle** | Production |
| **Owner** | team-platform |
| **System** | platform-infrastructure |
| **Dashboard** | https://auth.jeremymr.dev |

Identity provider and authentication server with OIDC/SSO support.

### Cert-Manager

| Property | Value |
|----------|-------|
| **Type** | Service |
| **Lifecycle** | Production |
| **Owner** | team-platform |
| **System** | platform-infrastructure |

Kubernetes certificate management for TLS certificates using Let's Encrypt.

### External Secrets

| Property | Value |
|----------|-------|
| **Type** | Service |
| **Lifecycle** | Production |
| **Owner** | team-platform |
| **System** | platform-infrastructure |

Kubernetes operator to sync secrets from external secret stores.

### Crossplane

| Property | Value |
|----------|-------|
| **Type** | Service |
| **Lifecycle** | Production |
| **Owner** | team-platform |
| **System** | platform-infrastructure |

Infrastructure as Code platform for managing cloud resources via Kubernetes.

### Backstage

| Property | Value |
|----------|-------|
| **Type** | Service |
| **Lifecycle** | Production |
| **Owner** | team-platform |
| **System** | platform-infrastructure |
| **Dashboard** | https://devdocs.jeremymr.dev |

Developer portal and service catalog for documenting infrastructure.

---

## Networking Components

### Envoy Gateway

| Property | Value |
|----------|-------|
| **Type** | Service |
| **Lifecycle** | Production |
| **Owner** | team-platform |
| **System** | networking |

Kubernetes ingress gateway using Envoy for HTTP routing.

### MetalLB

| Property | Value |
|----------|-------|
| **Type** | Service |
| **Lifecycle** | Production |
| **Owner** | team-platform |
| **System** | networking |

Bare metal load balancer for Kubernetes using BGP/ARP.

### External DNS

| Property | Value |
|----------|-------|
| **Type** | Service |
| **Lifecycle** | Production |
| **Owner** | team-platform |
| **System** | networking |

Kubernetes controller to manage DNS records in Cloudflare.

---

## Observability Components

### Grafana

| Property | Value |
|----------|-------|
| **Type** | Service |
| **Lifecycle** | Production |
| **Owner** | team-platform |
| **System** | observability |
| **Dashboard** | https://grafana.jeremymr.dev |

Observability and monitoring dashboard for visualizing metrics and logs.

### Prometheus

| Property | Value |
|----------|-------|
| **Type** | Service |
| **Lifecycle** | Production |
| **Owner** | team-platform |
| **System** | observability |

Monitoring system and time-series database for metrics collection.

### Loki

| Property | Value |
|----------|-------|
| **Type** | Service |
| **Lifecycle** | Production |
| **Owner** | team-platform |
| **System** | observability |

Log aggregation system designed for storing and querying logs.

### Tempo

| Property | Value |
|----------|-------|
| **Type** | Service |
| **Lifecycle** | Production |
| **Owner** | team-platform |
| **System** | observability |

Distributed tracing backend for storing and querying trace data.

### OpenTelemetry Collector

| Property | Value |
|----------|-------|
| **Type** | Service |
| **Lifecycle** | Production |
| **Owner** | team-platform |
| **System** | observability |

Telemetry collection agent for logs, metrics, and traces.

---

## Storage & Database Components

### Longhorn

| Property | Value |
|----------|-------|
| **Type** | Service |
| **Lifecycle** | Production |
| **Owner** | team-platform |
| **System** | storage-database |
| **Dashboard** | https://longhorn.jeremymr.dev |

Cloud-native distributed block storage for Kubernetes.

### Garage

| Property | Value |
|----------|-------|
| **Type** | Service |
| **Lifecycle** | Production |
| **Owner** | team-platform |
| **System** | storage-database |

S3-compatible distributed object storage for Kubernetes.

### CloudNativePG

| Property | Value |
|----------|-------|
| **Type** | Service |
| **Lifecycle** | Production |
| **Owner** | team-platform |
| **System** | storage-database |

Kubernetes operator for managing PostgreSQL clusters.

---

## Application Components

### Ghost

| Property | Value |
|----------|-------|
| **Type** | Website |
| **Lifecycle** | Production |
| **Owner** | team-platform |
| **System** | applications |
| **Blog** | https://ghost.jeremymr.dev |
| **Admin** | https://ghost-admin.jeremymr.dev |

Ghost blog platform for content publishing.

### Ghost Saima

| Property | Value |
|----------|-------|
| **Type** | Website |
| **Lifecycle** | Production |
| **Owner** | team-platform |
| **System** | applications |

Saima Ghost blog instance.

### Portfolio

| Property | Value |
|----------|-------|
| **Type** | Website |
| **Lifecycle** | Production |
| **Owner** | team-platform |
| **System** | applications |

Personal portfolio website.