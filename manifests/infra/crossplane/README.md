# Crossplane Configuration

This directory contains Crossplane configurations for declarative infrastructure management.

## Structure

```
crossplane/
├── providers/                    # Crossplane providers
│   ├── provider-terraform.yaml   # Terraform provider
│   ├── provider-kubernetes.yaml  # Kubernetes provider
│   ├── provider-helm.yaml        # Helm provider
│   ├── provider-kubernetes-config.yaml  # Kubernetes + Helm provider configs
│   ├── provider-kubernetes-rbac.yaml    # Provider RBAC bindings
│   └── provider-config.yaml      # Terraform provider configuration
├── secrets/                      # ExternalSecrets for Crossplane
│   ├── authentik-api-token.yaml  # Authentik API token
│   └── garage-admin-credentials.yaml  # Garage admin token
├── terraform-modules/            # Reusable Terraform modules
│   ├── authentik-oidc-app.yaml   # OIDC application module
│   └── garage-bucket.yaml        # Garage bucket module
├── functions/                    # Crossplane composition functions
│   ├── function-patch-and-transform.yaml
│   └── function-auto-ready.yaml
└── workspaces/                   # Workspace resources
    ├── longhorn-auth.yaml        # Longhorn Authentik app
    └── garage-loki-buckets.yaml  # Loki S3 buckets
└── kubesandbox/                  # KubeSandbox session XRD and composition
    ├── kubesandbox-session-xrd.yaml
    ├── kubesandbox-session-composition.yaml
```

## Prerequisites

### Authentik Bootstrap Configuration

Authentik is configured with **bootstrap environment variables** that automatically create the admin account and API token on first run. This eliminates the need for manual setup.

**Required Doppler Secrets for Authentik:**

| Key | Description | Example |
|-----|-------------|---------|
| `AUTHENTIK_SECRET_KEY` | Secret key for session encryption | Generate with `openssl rand -hex 32` |
| `AUTHENTIK_BOOTSTRAP_PASSWORD` | Initial admin password | Strong password |
| `AUTHENTIK_BOOTSTRAP_TOKEN` | API token for Crossplane | Generate with `openssl rand -hex 32` |
| `SMTP_HOST` | SMTP server hostname | `smtp.resend.com` |
| `SMTP_PORT` | SMTP server port | `587` |
| `SMTP_USERNAME` | SMTP authentication username | `resend` |
| `SMTP_PASSWORD` | SMTP authentication password | Your SMTP API key |
| `DB_PASSWORD` | PostgreSQL password | Strong password |
| `REDIS_PASSWORD` | Redis password | Strong password |

**Bootstrap Flow:**
```
1. Authentik starts for the first time
2. AUTHENTIK_BOOTSTRAP_EMAIL creates admin account
3. AUTHENTIK_BOOTSTRAP_PASSWORD sets admin password
4. AUTHENTIK_BOOTSTRAP_TOKEN creates API token automatically
5. Crossplane uses the same token from Doppler
```

### Garage Configuration

**Required Doppler Secrets for Garage:**

| Key | Description |
|-----|-------------|
| `GARAGE_ADMIN_TOKEN` | Garage admin API token |
| `GARAGE_API_URL` | Garage API URL (e.g., `garage.garage.svc:3903`) |

### Verify Crossplane is Running

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

### KubeSandbox Sessions

KubeSandbox uses a Crossplane composite resource to model one sandbox session as one declarative object.

- The claim kind is `KubeSandboxSession`
- The composite kind is `XKubeSandboxSession`
- The composition directly creates:
  - a session namespace
  - a `vcluster` Helm release
  - a default-deny NetworkPolicy
  - a long-running shell Pod
This is the session-first model, so the backend only needs to create and watch one Crossplane resource per session.

#### Connecting to the vCluster API

The current composition creates the vCluster control plane and mounts the generated kubeconfig into the shell Pod.

- vCluster writes a kubeconfig secret named `vc-<release>` into the session namespace.
- The shell Pod mounts that secret at `/kubeconfig` and uses `/kubeconfig/config` as `KUBECONFIG`.
- The kubeconfig now points at the vCluster service DNS name inside the session namespace, so the shell can talk to the vCluster API directly.

If you want a browser-friendly or external endpoint, we can still add an Ingress or LoadBalancer later, but it is no longer required for the in-cluster shell workflow.

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
