# Systems Reference

This page provides a reference for all systems in the GitOps Homelab catalog.

## System Hierarchy

```
homelab (root)
├── platform-infrastructure
├── observability
├── networking
├── storage-database
└── applications
```

## Systems

### Homelab

| Property | Value |
|----------|-------|
| **Type** | System |
| **Owner** | team-platform |
| **Parent** | None (root) |

GitOps Homelab Infrastructure - Complete umbrella system.

### Platform Infrastructure

| Property | Value |
|----------|-------|
| **Type** | System |
| **Owner** | team-platform |
| **Parent** | homelab |

Core platform infrastructure services including GitOps, secrets, certificates, and IaC.

**Components:**
- ArgoCD
- Authentik
- Cert-Manager
- External Secrets
- Crossplane
- Backstage

### Observability

| Property | Value |
|----------|-------|
| **Type** | System |
| **Owner** | team-platform |
| **Parent** | homelab |

Monitoring, logging, tracing, and observability stack.

**Components:**
- Grafana
- Prometheus
- Loki
- Tempo
- OpenTelemetry Collector

### Networking

| Property | Value |
|----------|-------|
| **Type** | System |
| **Owner** | team-platform |
| **Parent** | homelab |

Network infrastructure including ingress, load balancing, and DNS.

**Components:**
- Envoy Gateway
- MetalLB
- External DNS

### Storage & Database

| Property | Value |
|----------|-------|
| **Type** | System |
| **Owner** | team-platform |
| **Parent** | homelab |

Storage and database services including block storage, object storage, and databases.

**Components:**
- Longhorn
- Garage
- CloudNativePG

### Applications

| Property | Value |
|----------|-------|
| **Type** | System |
| **Owner** | team-platform |
| **Parent** | homelab |

User-facing applications and websites.

**Components:**
- Ghost
- Ghost Saima
- Portfolio