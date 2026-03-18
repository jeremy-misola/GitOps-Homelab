# APIs Reference

This page provides a reference for all APIs in the GitOps Homelab catalog.

## Authentik OIDC

| Property | Value |
|----------|-------|
| **Type** | OpenAPI |
| **Lifecycle** | Production |
| **Owner** | team-platform |
| **System** | platform-infrastructure |
| **Server** | https://auth.jeremymr.dev/application/o |

OIDC authentication API for single sign-on.

### Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/{application}/.well-known/openid-configuration` | GET | OpenID Connect Discovery |
| `/{application}/authorize/` | GET | Authorization Endpoint |
| `/{application}/token/` | POST | Token Endpoint |

---

## ArgoCD API

| Property | Value |
|----------|-------|
| **Type** | OpenAPI |
| **Lifecycle** | Production |
| **Owner** | team-platform |
| **System** | platform-infrastructure |
| **Server** | https://argocd.jeremymr.dev/api/v1 |

ArgoCD GitOps API for managing applications and clusters.

### Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/applications` | GET | List Applications |
| `/clusters` | GET | List Clusters |

---

## Ghost API

| Property | Value |
|----------|-------|
| **Type** | OpenAPI |
| **Lifecycle** | Production |
| **Owner** | team-platform |
| **System** | applications |
| **Server** | https://ghost.jeremymr.dev/ghost/api/v4/admin |

Ghost CMS Content API for retrieving posts, pages, and tags.

### Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/posts` | GET | List Posts |
| `/pages` | GET | List Pages |
| `/tags` | GET | List Tags |

---

## Garage S3 API

| Property | Value |
|----------|-------|
| **Type** | OpenAPI |
| **Lifecycle** | Production |
| **Owner** | team-platform |
| **System** | storage-database |
| **Server** | http://garage.garage.svc.cluster.local:3900 |

S3-compatible object storage API for storing and retrieving objects.

### Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/{bucket}` | GET | List Objects |
| `/{bucket}` | PUT | Create Bucket |
| `/{bucket}/{key}` | GET | Get Object |
| `/{bucket}/{key}` | PUT | Put Object |
| `/{bucket}/{key}` | DELETE | Delete Object |

---

## CloudNativePG API

| Property | Value |
|----------|-------|
| **Type** | OpenAPI |
| **Lifecycle** | Production |
| **Owner** | team-platform |
| **System** | storage-database |
| **Server** | postgresql://cluster-rw.cloudnativepg.svc.cluster.local:5432 |

CloudNativePG PostgreSQL database API.

### Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/databases` | GET | List Databases |
| `/query` | POST | Execute Query |