# Crossplane Configuration

This directory contains Crossplane configurations for declarative infrastructure management.

## Structure

```
crossplane/
├── providers/                    # Crossplane providers
│   ├── provider-terraform.yaml   # Terraform provider
│   └── provider-config.yaml      # Provider configuration
├── secrets/                      # ExternalSecrets for Crossplane
│   ├── authentik-api-token.yaml  # Authentik API token
│   └── garage-admin-credentials.yaml  # Garage admin token
├── terraform-modules/            # Reusable Terraform modules
│   ├── authentik-oidc-app.yaml   # OIDC application module
│   └── garage-bucket.yaml        # Garage bucket module
└── workspaces/                   # Workspace resources
    ├── longhorn-auth.yaml        # Longhorn Authentik app
    └── garage-loki-buckets.yaml  # Loki S3 buckets
```

## Prerequisites

1. **Add Authentik API Token to Doppler**:
   - Generate a token in Authentik Admin → Directory → Tokens
   - Add it to Doppler with key `AUTHENTIK_API_TOKEN`

2. **Add Garage Admin Token to Doppler**:
   - Get the admin token from your Garage deployment
   - Add it to Doppler with key `GARAGE_ADMIN_TOKEN`
   - Also add `GARAGE_API_URL` (e.g., `garage.garage.svc:3903`)

3. **Ensure Crossplane is running**:
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
    vars:
      - key: authentik_url
        value: "https://auth.jeremymr.dev"
      - key: authorization_flow
        value: "default-provider-authorization-explicit-consent"
      - key: invalidation_flow
        value: "default-provider-invalidation-flow"
    env:
      - name: TF_VAR_authentik_token
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

## Garage Bucket Management

Garage S3 buckets are managed via Crossplane using the `arsolitt/garagehq` Terraform provider. This allows declarative bucket creation with access keys.

### Workflow

```
Git Push → ArgoCD Sync → Crossplane creates Workspace
                            ↓
                    Terraform runs in-cluster
                            ↓
                    Garage buckets & keys created
                            ↓
                    S3 credentials written to K8s Secret
                            ↓
                    Applications reference the secret
```

### Creating a New Garage Bucket

Create a new Workspace in `workspaces/`:

```yaml
apiVersion: tf.upbound.io/v1beta1
kind: Workspace
metadata:
  name: garage-myapp-bucket
  namespace: crossplane-system
spec:
  forProvider:
    source: Inline
    module: |
      terraform {
        required_providers {
          garage = {
            source  = "arsolitt/garagehq"
            version = ">= 0.0.1"
          }
        }
      }

      variable "garage_host" { type = string }
      variable "garage_scheme" { type = string default = "http" }
      variable "garage_token" { type = string sensitive = true }

      provider "garage" {
        host   = var.garage_host
        scheme = var.garage_scheme
        token  = var.garage_token
      }

      resource "garage_bucket" "bucket" {
        global_alias = "myapp-data"
      }

      resource "garage_key" "key" {
        name = "myapp-key"
      }

      resource "garage_bucket_key" "bucket_key" {
        bucket_id     = garage_bucket.bucket.id
        access_key_id = garage_key.key.access_key_id
        read          = true
        write         = true
        owner         = false
      }

      output "access-key-id" {
        value = garage_key.key.access_key_id
      }

      output "secret-access-key" {
        value     = garage_key.key.secret_access_key
        sensitive = true
      }

    vars:
      - key: garage_host
        value: "garage.garage.svc:3903"
      - key: garage_scheme
        value: "http"

    env:
      - name: TF_VAR_garage_token
        secretKeyRef:
          namespace: crossplane-system
          name: garage-admin-credentials
          key: garage-admin-token

  writeConnectionSecretToRef:
    name: myapp-s3-credentials
    namespace: myapp-namespace

  providerConfigRef:
    name: terraform-config
```

### Garage Bucket Outputs

The Workspace writes the following outputs to the connection secret:
- `access-key-id` - S3 Access Key ID
- `secret-access-key` - S3 Secret Access Key
- `bucket-chunks`, `bucket-ruler`, `bucket-admin` - Bucket IDs (if multiple buckets)

Applications can reference these credentials to access S3 storage:

```yaml
env:
  - name: AWS_ACCESS_KEY_ID
    valueFrom:
      secretKeyRef:
        name: myapp-s3-credentials
        key: access-key-id
  - name: AWS_SECRET_ACCESS_KEY
    valueFrom:
      secretKeyRef:
        name: myapp-s3-credentials
        key: secret-access-key
  - name: S3_ENDPOINT
    value: "http://garage.garage.svc:3900"
```

## Sync Waves

- `providers/` - Sync wave 0 (installed first)
- `secrets/` - Sync wave 5 (after external-secrets is ready)
- `terraform-modules/` - Sync wave 5 (same as secrets)
- `workspaces/` - Sync wave 10 (after providers are ready)
