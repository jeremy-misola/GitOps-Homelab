# GitOps Sync Chain

To manage many different configurations, I'm using a multi-stage **ArgoCD sync chain**. This allows for a "bootstrap-from-zero" workflow where applying a single file triggers the recursive deployment of the entire stack.

## Architecture

![ArgoCD App of Apps Architecture](../images/argo-architecture.svg)

## Repository Lifecycle

The sync chain flows through several stages:

### 1. Bootstrap Entry Point

**`bootstrap/`**: Contains the `root-app.yaml`. This is the manual entry point.

```yaml
# bootstrap/root-app.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: root
  namespace: argocd
spec:
  source:
    path: categories
    repoURL: https://github.com/jeremy-misola/GitOps-Homelab
  destination:
    namespace: argocd
    server: https://kubernetes.default.svc
```

### 2. Category Applications

**`categories/`**: Defines parent "Category Apps" (Infrastructure vs. Applications) that orchestrate the order of operations.

- `infrastructure.yaml` - Sync wave -5
- `applications.yaml` - Sync wave 0

### 3. Individual Applications

**`argocd-apps/`**: Contains individual `Application` manifests for services like `istio` or `ghost`.

Each application references:
- Helm chart or Git repository
- Values overrides
- Target namespace

### 4. Configuration Manifests

**`manifests/`**: The configuration source, containing:
- Helm `values.yaml` overrides
- Envoy Gateway `HTTPRoute` definitions
- External Secrets `SecretStores` and `ExternalSecrets`
- Crossplane `Workspaces` and providers

## Sync Waves

Applications are deployed in ordered waves:

| Wave | Description | Examples |
|------|-------------|----------|
| -10 | Prerequisites | Namespace creation |
| -5 | Infrastructure Core | cert-manager, external-secrets, longhorn |
| 0 | Core Services | envoy-gateway, authentik |
| 5 | Monitoring | prometheus, loki, tempo |
| 10 | Applications | ghost, backstage, portfolio |
| 20 | Dependencies | Database migrations, secrets |

## Directory Structure

```
GitOps-Homelab/
├── bootstrap/
│   └── root-app.yaml          # Entry point
├── categories/
│   ├── infrastructure.yaml    # Infrastructure ApplicationSet
│   └── applications.yaml      # Applications ApplicationSet
├── argocd-apps/
│   ├── infrastructure/
│   │   ├── cert-manager/
│   │   ├── external-secrets/
│   │   ├── envoy-gateway/
│   │   └── ...
│   └── apps/
│       ├── ghost/
│       ├── backstage/
│       └── portfolio/
└── manifests/
    ├── infra/
    │   ├── cert-manager/
    │   ├── crossplane/
    │   └── envoy-gateway/
    └── apps/
        ├── ghost/
        ├── backstage/
        └── portfolio/
```

## Bootstrap Process

1. **Manual Trigger**: Apply `root-app.yaml` to the cluster
2. **ArgoCD Sync**: ArgoCD creates the root Application
3. **Category Discovery**: Root app references `categories/` directory
4. **Infrastructure Sync**: Infrastructure ApplicationSet deploys (wave -5)
5. **Application Sync**: Applications ApplicationSet deploys (wave 0+)
6. **Convergence**: System reaches desired state

## Adding New Applications

1. Create directory in `argocd-apps/apps/<name>/`
2. Add Application manifest(s):
   - `<name>-helm-app.yaml` - Helm chart reference
   - `<name>-git-app.yaml` - Git manifest reference (optional)
3. Create manifests in `manifests/apps/<name>/`
4. ArgoCD automatically discovers and deploys

## Rollback & Recovery

Since all configuration is in Git:

1. **Identify issue**: Check ArgoCD dashboard
2. **Revert commit**: `git revert <commit>`
3. **ArgoCD sync**: Automatic or manual sync
4. **Recovery**: Cluster converges to previous state

## Best Practices

- **Declarative Everything**: All config in Git, no manual changes
- **Sync Waves**: Use waves for dependency ordering
- **Self-Healing**: Enable ArgoCD self-heal and prune
- **Health Checks**: Define health checks for applications