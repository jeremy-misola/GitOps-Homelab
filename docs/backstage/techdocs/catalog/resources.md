# Resources Reference

This page provides a reference for all infrastructure resources in the GitOps Homelab catalog.

## Kubernetes Cluster

| Property | Value |
|----------|-------|
| **Type** | kubernetes-cluster |
| **Owner** | team-platform |
| **System** | homelab |

Primary Kubernetes homelab cluster.

---

## Cloudflare DNS

| Property | Value |
|----------|-------|
| **Type** | dns-provider |
| **Owner** | team-platform |
| **System** | networking |

Cloudflare DNS provider for domain management.

---

## Garage Storage

| Property | Value |
|----------|-------|
| **Type** | s3-bucket |
| **Owner** | team-platform |
| **System** | storage-database |

S3-compatible object storage buckets for logs and data.

---

## Loki Storage Bucket

| Property | Value |
|----------|-------|
| **Type** | s3-bucket |
| **Owner** | team-platform |
| **System** | storage-database |
| **Depends On** | garage-storage |

S3 bucket for Loki log storage.

---

## Longhorn Storage

| Property | Value |
|----------|-------|
| **Type** | storage |
| **Owner** | team-platform |
| **System** | storage-database |

Distributed block storage for Kubernetes persistent volumes.

---

## Portfolio Database

| Property | Value |
|----------|-------|
| **Type** | database |
| **Owner** | team-platform |
| **System** | storage-database |

PostgreSQL database for the portfolio application.

---

## Ghost Database

| Property | Value |
|----------|-------|
| **Type** | database |
| **Owner** | team-platform |
| **System** | storage-database |

Database storage for Ghost blog content.

---

## GitHub Repository

| Property | Value |
|----------|-------|
| **Type** | repository |
| **Owner** | team-platform |
| **System** | platform-infrastructure |
| **URL** | https://github.com/jeremy-misola/GitOps-Homelab |

GitOps repository for infrastructure as code.