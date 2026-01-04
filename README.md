# GitOps-Homelab

[![Kubernetes](https://img.shields.io/badge/kubernetes-%23326ce5.svg?style=flat&logo=kubernetes&logoColor=white)](https://kubernetes.io)
[![ArgoCD](https://img.shields.io/badge/Argo%20CD-EF7B4D?style=flat&logo=argo-cd&logoColor=white)](https://argoproj.github.io/cd/)
[![Istio](https://img.shields.io/badge/Istio-466BB0?style=flat&logo=istio&logoColor=white)](https://istio.io/)

This repository serves as the **Single Source of Truth** for my homelab. Developed over the last eight months as part of my transition into DevOps.

The cluster is managed through **Declarative GitOps** and the **App of Apps pattern**, ensuring the entire infrastructure—from networking to end-user services—is reproducible, version-controlled, and self-healing.

---

## System Architecture

The environment is architected into two logical layers: **Infrastructure Core** (Platform Primitives) and **Application Workloads** (Service Layer).

### Technical Stack

| Layer | Component | Implementation |
| :--- | :--- | :--- |
| **Orchestration** | Runtime | **K3s** (Lightweight Kubernetes) |
| **GitOps** | CD Engine | **ArgoCD** |
| **Networking** | Service Mesh & L2 | **Istio**, **Envoy Gateway**, **MetalLB** |
| **Storage** | Block & S3 | **Longhorn** (CSI), **Garage S3** |
| **Security** | Identity & Secrets | **Authentik** (OIDC), **External Secrets (ESO)**, **Cert-Manager** |
| **Observability** | LGTM Stack | **Loki**, **Grafana**, **Tempo**, **Prometheus** |

---

## Repository Lifecycle (The Sync Chain)

To manage many different configurations, I'm using a multi-stage **ArgoCD sync chain**. This allows for a "bootstrap-from-zero" workflow where applying a single file triggers the recursive deployment of the entire stack.

1.  **`bootstrap/`**: Contains the `root-app.yaml`. This is the manual entry point.
2.  **`categories/`**: Defines parent "Category Apps" (Infrastructure vs. Applications) that orchestrate the order of operations.
3.  **`argocd-apps/`**: Contains individual `Application` manifests for services like `istio` or `ghost`.
4.  **`charts/`**: The configuration source, containing Helm `values.yaml` overrides, Istio `VirtualServices`, and ESO `SecretStores`.
<img width="1886" height="1138" alt="image" src="https://github.com/user-attachments/assets/251f3656-f95c-4b20-992e-951502e0ed10" />


---

## Service Catalog

### User-Facing Applications
*   **[Ghost](https://ghost.jeremymr.dev/):** My personal blog platform. Engineered with a **MariaDB** backend and **Longhorn** for persistent volume management.
*   **[Kleff](https://kleff.io):** A microservice architecture based PaaS (Vercel alternative). This serves as the testing ground for **Istio service mesh** traffic shifting and **distributed tracing with Tempo**.
*   **Obsidian Vault Sync:** A **CouchDB** NoSQL cluster configured for cross-device synchronization of my Obsidian knowledge base.

### Infrastructure Services
*   **Garage S3:** Self-hosted, distributed S3 storage. Acts as the primary backup target for Longhorn snapshots and the long-term storage backend for Loki logs.
*   **External Secrets (ESO):** Decouples secret management from Git. ESO dynamically pulls credentials from an encrypted provider and injects them as native K8s secrets at runtime.
*   **Identity Management:** **Authentik** serves as the cluster's OIDC provider, enforcing unified SSO across internal administrative dashboards.

---

## Observability & Reliability

The **LGTM stack** provides deep visibility into the cluster's health and performance:
- **Metrics & Alerting:** Prometheus monitors node/pod resources with Grafana for visualization.
- **Log Aggregation:** Loki handles log streams from the control plane and workloads.
- **Distributed Tracing:** Tempo tracks requests through the Kleff Microservices to identify latency bottlenecks.
- **Data Durability:** Automated volume backups are replicated to off-site S3 storage via Longhorn's recurring job system.

---
*Maintained by [Jeremy Misola](http://github.com/jeremy-misola) — DevOps Engineer & Platform Enthusiast.*

---
