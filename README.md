```
.
├── argocd-apps
│   ├── apps
│   └── infrastructure
│       ├── authentik
│       │   └── authentik.yaml
│       └── monitoring
│       │   └── kube-prometheus.yaml
│       └── etc...
├── bootstrap (grandparent)
│   └── root-app.yaml
├── categories (parent argocd applications)
│   ├── applications.yaml
│   └── infrastructure.yaml
└── charts (includes manifests for different apps)
    ├── cert-manager
    │   └── cluster-issuer.yaml
    ├── external-secrets
    │   ├── authentik-secrets.yaml
    │   ├── cloudflare-secret.yaml
    │   └── secret-store.yaml
    └── etc...
```
