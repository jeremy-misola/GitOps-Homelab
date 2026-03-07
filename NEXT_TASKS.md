# Next Tasks to Complete

This document outlines the remaining tasks needed to make the repository fully functional after the ApplicationSet migration and charts directory restructuring.

## 🚨 Critical: Update Path References

The following config files still reference old paths that no longer exist. **These must be updated before the repository will work.**

### Application Configs

| File | Current Path | Correct Path | Status |
|------|-------------|--------------|--------|
| `argocd-apps/apps/portfolio/portfolio-git-app.yaml` | `charts/portfolio` | `charts/apps/portfolio` | ❌ Needs update |

### Infrastructure Configs

| File | Current Path | Correct Path | Status |
|------|-------------|--------------|--------|
| `argocd-apps/infrastructure/cert-manager/cert-manager-git-app.yaml` | `charts/cert-manager` | `charts/infrastructure/cert-manager` | ❌ Needs update |
| `argocd-apps/infrastructure/envoy-gateway/envoy-gateway-git-app.yaml` | `charts/envoy-gateway` | `charts/infrastructure/envoy-gateway` | ❌ Needs update |
| `argocd-apps/infrastructure/metallb/metallb-git-app.yaml` | `charts/metallb` | `charts/infrastructure/metallb` | ❌ Needs update |
| `argocd-apps/infrastructure/external-secrets/external-secrets-git-app.yaml` | `charts/external-secrets` | `charts/infrastructure/secrets` | ❌ Needs update |

---

## 📋 Task Checklist

### Phase 1: Fix Path References

- [ ] Update `argocd-apps/apps/portfolio/portfolio-git-app.yaml`
  ```yaml
  appPath: charts/apps/portfolio
  ```

- [ ] Update `argocd-apps/infrastructure/cert-manager/cert-manager-git-app.yaml`
  ```yaml
  appPath: charts/infrastructure/cert-manager
  ```

- [ ] Update `argocd-apps/infrastructure/envoy-gateway/envoy-gateway-git-app.yaml`
  ```yaml
  appPath: charts/infrastructure/envoy-gateway
  ```

- [ ] Update `argocd-apps/infrastructure/metallb/metallb-git-app.yaml`
  ```yaml
  appPath: charts/infrastructure/metallb
  ```

- [ ] Update `argocd-apps/infrastructure/external-secrets/external-secrets-git-app.yaml`
  ```yaml
  appPath: charts/infrastructure/secrets
  ```

### Phase 2: Create Shared Secrets Application

The `charts/shared/` directory contains shared resources that need their own Application:

- [ ] Create `argocd-apps/infrastructure/shared/shared-git-app.yaml`
  ```yaml
  name: shared-secrets
  namespace: external-secrets
  syncWave: "0"
  repoURL: https://github.com/jeremy-misola/GitOps-Homelab
  targetRevision: develop
  appPath: charts/shared
  ```

- [ ] Create `charts/shared/` directory if missing (secret-store.yaml, cloudflare-secret.yaml, saima-cloudflare-secret.yaml)

### Phase 3: Verify Directory Structure

Ensure all referenced directories exist:

```
charts/
├── apps/
│   ├── ghost/
│   ├── ghost-saima/
│   └── portfolio/
├── infrastructure/
│   ├── cert-manager/
│   ├── envoy-gateway/
│   ├── metallb/
│   ├── secrets/
│   └── ...
└── shared/
    ├── secret-store.yaml
    ├── cloudflare-secret.yaml
    └── saima-cloudflare-secret.yaml
```

### Phase 4: Test & Deploy

- [ ] Commit all changes
- [ ] Push to remote repository
- [ ] Verify ArgoCD picks up the changes
- [ ] Check ApplicationSet generates all Applications correctly
- [ ] Monitor sync status in ArgoCD UI

---

## 🏗️ Current Repository Structure

```
GitOps-Homelab/
├── argocd-apps/
│   ├── apps/                    # Application configs
│   │   ├── ghost/
│   │   │   ├── ghost-helm-app.yaml
│   │   │   └── ghost-saima-helm-app.yaml
│   │   └── portfolio/
│   │       └── portfolio-git-app.yaml
│   └── infrastructure/          # Infrastructure configs
│       ├── authentik/
│       ├── cert-manager/
│       ├── cloudnativepg/
│       ├── envoy-gateway/
│       ├── external-secrets/
│       ├── externalDNS/
│       ├── garage/
│       ├── loki/
│       ├── longhorn/
│       ├── metallb/
│       ├── monitoring/
│       ├── opentelemetry-collector/
│       └── tempo/
├── bootstrap/
│   └── root-app.yaml
├── categories/
│   ├── applications.yaml        # ApplicationSet for apps
│   └── infrastructure.yaml      # ApplicationSet for infra
├── charts/
│   ├── apps/                    # App-specific manifests
│   ├── infrastructure/          # Infra manifests
│   └── shared/                  # Shared resources
└── docs/
```

---

## 🔗 ApplicationSet Configuration

The ApplicationSets use Git File Generator pattern:

- **Helm apps**: `*-helm-app.yaml` files
- **Git apps**: `*-git-app.yaml` files

Each config file contains:
```yaml
name: <app-name>
namespace: <target-namespace>
syncWave: "<number>"
repoURL: <helm-repo-or-git-url>
chart: <chart-name>           # For Helm only
targetRevision: <version>
appPath: <path-in-repo>       # For Git only
values: |                     # For Helm only
  <yaml-values>
```

---

## ⚠️ Known Issues

1. **Shared directory may be empty** - The `charts/shared/` directory was created but may need files restored
2. **Ghost apps use OCI chart** - No git-path updates needed for ghost-helm-app configs
3. **External secrets config** - May need to be split between infra and shared

---

## 📝 Notes

- All paths in `appPath` should be relative to the repository root
- The ApplicationSet automatically discovers new `*-helm-app.yaml` and `*-git-app.yaml` files
- Adding a new app/infra component only requires creating a config file in the appropriate directory