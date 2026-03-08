# Crossplane Configuration

This directory contains Crossplane configurations for declarative infrastructure management.

## Structure

```
crossplane/
├── providers/                    # Crossplane providers
│   ├── provider-terraform.yaml   # Terraform provider
│   └── provider-config.yaml      # Provider configuration
├── secrets/                      # ExternalSecrets for Crossplane
│   └── authentik-api-token.yaml  # Authentik API token
├── terraform-modules/            # Reusable Terraform modules
│   └── authentik-oidc-app.yaml   # OIDC application module
└── workspaces/                   # Workspace resources
    └── longhorn-auth.yaml        # Longhorn Authentik app
```

## Prerequisites

1. **Add Authentik API Token to Doppler**:
   - Generate a token in Authentik Admin → Directory → Tokens
   - Add it to Doppler with key `AUTHENTIK_API_TOKEN`

2. **Ensure Crossplane is running**:
   ```bash
   kubectl get pods -n crossplane-system
   ```

## How It Works

### Workflow

```
Git Push → ArgoCD Sync → Crossplane creates Workspace
                            ↓
                    Terraform runs in-cluster
                            ↓
                    Authentik Provider & Application created
                            ↓
                    Client credentials written to K8s Secret
                            ↓
                    SecurityPolicy references the secret
```

### Creating a New Authentik Application

Create a new Workspace in `workspaces/`:

```yaml
apiVersion: tf.upbound.io/v1beta1
kind: Workspace
metadata:
  name: myapp-auth
  namespace: crossplane-system
spec:
  forProvider:
    source: Inline
    module: |
      # Terraform config here (see longhorn-auth.yaml for example)
    variables:
      - key: authentik_url
        value: "https://auth.jeremymr.dev"
      - key: authentik_token
        sensitive: true
        valueFrom:
          secretKeyRef:
            namespace: crossplane-system
            name: authentik-api-token
            key: token
  writeConnectionSecretToRef:
    name: myapp-client-secret
    namespace: myapp-namespace
  providerConfigRef:
    name: terraform-config
```

## Outputs

The Workspace writes the following outputs to the connection secret:
- `client_id` - OAuth2 Client ID
- `client_secret` - OAuth2 Client Secret

These can be referenced in your SecurityPolicy:

```yaml
spec:
  oidc:
    clientID: "<from-secret>"
    clientSecret:
      name: "myapp-client-secret"
```

## Sync Waves

- `providers/` - Sync wave 0 (installed first)
- `secrets/` - Sync wave 5 (after external-secrets is ready)
- `workspaces/` - Sync wave 10 (after providers are ready)