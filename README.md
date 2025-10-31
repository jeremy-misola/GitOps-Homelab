
# My Kubernetes Homelab - A GitOps-Driven Personal Cloud Infrastructure

This repository is my personal Kubernetes-based homelab for self-hosting applications and services and learning production grade tools.

## Overview & Motivation

I built this homelab to gain hands-on expertise with cloud-native technologies, deepen my understanding of Kubernetes, and implement modern DevOps practices in a real-world scenario. I wanted to migrate my entire workflow to self-hosted tools while gaining experience with the very tools I will be using on the job.

## Architectural Principles & Design

This homelab is engineered with a focus on a few principles:

*   **GitOps-Centric:** The entire infrastructure and application deployments are managed declaratively through a GitOps workflow using **Argo CD**. All desired states are version-controlled in Git, enabling automated deployments, seamless rollbacks, and a single source of truth for the entire environment.
*   **App-of-Apps Pattern:** The cluster uses the Argo CD "App-of-Apps" pattern for managing application lifecycles and dependencies. This allows a scalable and organized approach to deploying multiple interdependent services.

## Core Infrastructure Components

Each component in this homelab was chosen for a specific reason and plays an important role in the overall functionality:

*   **Kubernetes (K3s/Vanilla):** The foundational container orchestration platform, providing robust resource management, scheduling, and high availability for all deployed applications.
*   **Argo CD:** Serves as the continuous delivery tool, actively synchronizing the desired state defined in this Git repository with the actual state in the Kubernetes cluster. It automates deployments, manages application lifecycles, and enforces declarative configuration.
*   **Helm:** Employed for packaging and deploying applications, standardizing configurations, and facilitating repeatable, version-controlled deployments across the cluster.
*   **Tailscale & Kubernetes Operator:** Provides a secure, zero-config mesh VPN, enabling encrypted and authenticated access to homelab services from any authorized device. Its Kubernetes Operator automates the configuration and management of Tailscale within the cluster, demonstrating operator pattern knowledge.
*   **MetalLB:** Implements a bare-metal load balancer for Kubernetes, dynamically providing external IP addresses to services within the self-hosted environment, overcoming the lack of traditional cloud provider load balancers.
*   **External Secrets Operator (ESO) + Doppler:** Securely injects secrets from Doppler (a centralized secrets management platform) into Kubernetes. This decouples secret storage from application code, enhances security posture, and streamlines secret rotation and management.
*   **Ingress Nginx:** Manages external HTTP/HTTPS access to services within the cluster, handling intelligent routing, load balancing, and SSL/TLS termination for internal applications.
*   **Longhorn:** Provides distributed block storage for Kubernetes, ensuring data persistence, high availability, and snapshot capabilities for stateful applications, crucial for data integrity and disaster recovery.
*   **Istio (In progress):** Provides a service mesh architecture to handle fine-grained communication within the cluster.

## What's Running on the Homelab?

Here's a look at some of the applications and services I'm currently self-hosting:

*   **Kube-Prometheus Stack:** A comprehensive monitoring and alerting solution (Prometheus, Grafana, Alertmanager), providing deep insights into cluster health, resource utilization, and application performance through rich metrics and customizable dashboards. Critical for operational excellence and proactive issue resolution.
*   **CouchDB:** A NoSQL database leveraged for secure synchronization of Obsidian notes across devices, showcasing the deployment and management of stateful applications.
*   **AdGuard Home:** A network-wide DNS filtering and ad-blocking solution, enhancing network security and privacy for all connected devices.
*   **Immich:** A self-hosted photo and video backup solution, demonstrating the handling of large media files, persistent storage, and complex application deployments.
*   **Stirling-PDF:** A web-based suite of tools for PDF manipulation, deployed for utility and demonstrating a stateless application deployment.
*   **Excalidraw:** A virtual whiteboard for sketching hand-drawn like diagrams.
*   **Nextcloud:** A self-hosted file synchronization and sharing solution.

## Observability & Operational Excellence

Proactive monitoring and robust observability are core tenets of this homelab:

*   **Monitoring:** The Kube-Prometheus stack collects extensive metrics from Kubernetes components, nodes, and all deployed applications. Custom Grafana dashboards provide real-time visualization of key performance indicators (CPU, memory, network I/O, application-specific metrics).
*   **Alerting:** Alertmanager is configured to send notifications for critical events and threshold breaches, ensuring proactive incident response and maintaining service reliability.
*   **Logging:** Centralized logging solution to aggregate and analyze logs from all pods and nodes, facilitating quicker debugging and operational insights.

## Networking & Security Posture

Security and controlled access are paramount in this self-hosted environment:

*   **Secure Access:** Tailscale provides an encrypted, least-privilege access model to the homelab, eliminating the need for public-facing ports or complex firewall rules and simplifying remote access.
*   **Secrets Management:** Rigorous secrets management through External Secrets Operator and Doppler ensures sensitive data (API keys, database credentials) is never hardcoded, is securely stored, and securely injected at runtime.
*   **Ingress Security:** SSL/TLS termination is handled at the Ingress Nginx layer, ensuring all external communication to exposed services is encrypted.

## Future Goals

This project is a continuous learning experience, and here's what I have planned next:

*   Exploring **Crossplane** for GitOps-driven infrastructure provisioning beyond just applications.
*   Investigating more advanced backup and disaster recovery strategies for critical data within Longhorn.
*   Experimenting with a service mesh (e.g., Istio, Linkerd) for enhanced traffic management, security policies, and observability at the application layer.
*   Deepening knowledge in Kubernetes security best practices and cluster hardening.

## Skills Demonstrated

This project serves as a comprehensive demonstration of the following technical skills and expertise:

*   **Kubernetes:** Cluster administration, application deployment, resource management, custom resource definitions (CRDs), and operator pattern utilization.
*   **GitOps:** Implementing and managing continuous delivery with Argo CD, declarative configuration, and Git-driven infrastructure management.
*   **Networking:** Load balancing (MetalLB), secure mesh VPN (Tailscale), Ingress management (Nginx), and network security principles.
*   **Storage:** Distributed persistent storage management (Longhorn), stateful application deployment, and data resilience.
*   **Observability:** Implementing and utilizing Prometheus, Grafana, and Alertmanager for robust monitoring, logging, and alerting.
*   **Security:** Secrets management (External Secrets Operator, Doppler), secure access strategies, and general security best practices.
*   **Automation:** Infrastructure as Code (IaC) principles, automated deployments, and streamlining operational workflows.
*   **System Design & Architecture:** Planning and implementing a scalable, resilient, and observable infrastructure.
*   **Problem-Solving & Independent Learning:** Identifying challenges in a self-hosted environment and developing effective solutions through continuous learning and experimentation.
