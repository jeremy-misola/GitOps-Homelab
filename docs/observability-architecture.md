# Observability Architecture — Self-Hosted (No Grafana Cloud)

## Current State

Your stack is already mostly self-hosted. Here's what you have today:

| Signal | Collector | Storage | Where it goes |
|--------|-----------|---------|---------------|
| Metrics | kube-prometheus-stack | — | **Grafana Cloud** via `remoteWrite` |
| Logs | OTEL Collector (daemonset) | Loki → Garage (S3) | Loki + **Grafana Cloud** via OTLP |
| Traces | OTEL Collector (daemonset) | Tempo | Tempo + **Grafana Cloud** via OTLP |

Grafana, Loki, and Tempo are all self-hosted and backed by Garage (your S3-compatible object store). The only thing hitting Grafana Cloud is:

1. Prometheus `remoteWrite` → `prometheus-prod-32-prod-ca-east-0.grafana.net` (primary cost driver — this is high-volume)
2. OTEL `otlphttp/grafana` → `otlp-gateway-prod-ca-east-0.grafana.net` (logs + traces duplicated to cloud)

Both clusters (dev and prod) have the same `remoteWrite` configured, so you're burning double the quota.

---

## Target Architecture

Add **Grafana Mimir** as your self-hosted metrics backend. Mimir is literally what Grafana Cloud Metrics runs on — it's a drop-in replacement for the `remoteWrite` endpoint. It stores data in object storage, which you already have with Garage.

```
┌──────────────────────────────────────────────────────────┐
│                     Production Cluster                    │
│                                                          │
│  ┌─────────────────────┐    ┌──────────────────────────┐ │
│  │   kube-prometheus   │    │     OTEL Collector       │ │
│  │  (dev + prod scrape)│    │      (daemonset)         │ │
│  └──────────┬──────────┘    └──────┬────────┬──────────┘ │
│             │ remoteWrite          │ logs   │ traces      │
│             ▼                      ▼        ▼            │
│  ┌──────────────────┐  ┌────────────────┐  ┌──────────┐  │
│  │  Grafana Mimir   │  │      Loki      │  │  Tempo   │  │
│  │  (metrics TSDB)  │  │  (log storage) │  │ (traces) │  │
│  └────────┬─────────┘  └───────┬────────┘  └────┬─────┘  │
│           │                    │                │        │
│           └──────────┬─────────┘                │        │
│                      │                          │        │
│                      ▼                          │        │
│             ┌──────────────────┐                │        │
│             │  Garage (S3)     │◄───────────────┘        │
│             │  Object Store    │                         │
│             └──────────────────┘                         │
│                                                          │
│  ┌───────────────────────────────────────────────────┐   │
│  │  Grafana  (datasources: Mimir, Loki, Tempo)       │   │
│  └───────────────────────────────────────────────────┘   │
└──────────────────────────────────────────────────────────┘

┌──────────────────────────────────┐
│         Dev Cluster              │
│                                  │
│  ┌─────────────────────┐         │
│  │   kube-prometheus   │         │
│  └──────────┬──────────┘         │
│             │ remoteWrite        │
│             │ (to prod Mimir)    │
└─────────────┼────────────────────┘
              │
              ▼ (cross-cluster)
         Grafana Mimir (prod)
```

### Why Mimir over Thanos or VictoriaMetrics

**Mimir** is the right choice here because:

- You already run the Grafana stack (Loki, Tempo, Grafana) — Mimir fits naturally
- Uses Garage for object storage just like Loki does — same Crossplane/Terraform pattern you already have for bucket provisioning
- Supports multi-tenancy, so you can separate dev and prod metrics with `X-Scope-OrgID` headers (same pattern as Loki)
- The `remoteWrite` URL swap in Prometheus is trivial — just change the endpoint
- Grafana has a native Mimir datasource (it's a Prometheus-compatible API)

**Thanos** requires a sidecar on each Prometheus pod and a Query layer — more moving parts. **VictoriaMetrics** is excellent but introduces a different ecosystem when you're already all-in on Grafana LGTM stack.

---

## Changes Required

### 1. Add Mimir to your operator stack

Add to `operators-helm/values/values-prd.yaml` (after Garage, before kube-prometheus):

```yaml
- name: mimir
  namespace: mimir
  syncWave: 30                      # same wave as loki/tempo
  repoURL: https://grafana.github.io/helm-charts
  chart: mimir-distributed
  targetRevision: 5.6.0
  preResources:
    enabled: true
```

For a homelab, start with the monolithic mode (single binary) instead of distributed — it's much simpler and handles millions of series without issue:

```yaml
- name: mimir
  namespace: mimir
  syncWave: 30
  repoURL: https://grafana.github.io/helm-charts
  chart: mimir-distributed           # or just "grafana-mimir" for monolithic
  targetRevision: 5.6.0
  preResources:
    enabled: true
```

### 2. Mimir values — backed by Garage S3

Create `operators-helm/operators/mimir/values/chart/values-prd.yaml`:

```yaml
# Monolithic deployment — single binary, simpler for homelab
mimir:
  structuredConfig:
    common:
      storage:
        backend: s3
        s3:
          endpoint: garage.garage.svc.cluster.local:3900
          region: garage
          access_key_id: ${S3_ACCESS_KEY}
          secret_access_key: ${S3_SECRET_KEY}
          insecure: true

    blocks_storage:
      s3:
        bucket_name: mimir-blocks

    alertmanager_storage:
      s3:
        bucket_name: mimir-alertmanager

    ruler_storage:
      s3:
        bucket_name: mimir-ruler

    # Multi-tenancy: prod cluster sends with tenant "prod", dev with "dev"
    multitenancy_enabled: true

    limits:
      # Adjust based on your cardinality
      ingestion_rate: 100000
      max_global_series_per_user: 1000000

extraEnv:
  - name: S3_ACCESS_KEY
    valueFrom:
      secretKeyRef:
        name: mimir-s3-credentials
        key: access-key-id
  - name: S3_SECRET_KEY
    valueFrom:
      secretKeyRef:
        name: mimir-s3-credentials
        key: secret-access-key
```

### 3. Provision Mimir buckets in Garage

Create `operators-helm/operators/mimir/pre-resources/garage-mimir-buckets.yaml` — mirror the Loki Terraform Workspace pattern:

```yaml
apiVersion: tf.upbound.io/v1beta1
kind: Workspace
metadata:
  name: garage-mimir-buckets
  namespace: crossplane-system
  annotations:
    argocd.argoproj.io/sync-wave: "17"
spec:
  forProvider:
    source: Inline
    module: |
      # ... (same provider block as Loki) ...

      resource "garage_bucket" "mimir_blocks"      { global_alias = "mimir-blocks" }
      resource "garage_bucket" "mimir_alertmanager" { global_alias = "mimir-alertmanager" }
      resource "garage_bucket" "mimir_ruler"       { global_alias = "mimir-ruler" }

      resource "garage_key" "mimir" { name = "mimir-key" }

      # Grant access to all three buckets
      resource "garage_bucket_key" "blocks" {
        bucket_id     = garage_bucket.mimir_blocks.id
        access_key_id = garage_key.mimir.access_key_id
        read          = true
        write         = true
      }
      # ... repeat for alertmanager and ruler ...

      output "access-key-id"     { value = garage_key.mimir.access_key_id }
      output "secret-access-key" { value = garage_key.mimir.secret_access_key  sensitive = true }

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
    name: mimir-s3-credentials
    namespace: mimir

  providerConfigRef:
    name: terraform-config
```

### 4. Update Prometheus remoteWrite — both clusters

**`values-prd.yaml`** — change `remoteWrite` from Grafana Cloud to Mimir:

```yaml
# BEFORE
prometheus:
  prometheusSpec:
    remoteWrite:
      - url: https://prometheus-prod-32-prod-ca-east-0.grafana.net./api/prom/push
        basicAuth:
          username:
            name: grafana-cloud-token
            key: prometheus-username
          password:
            name: grafana-cloud-token
            key: access-token
    externalLabels:
      cluster: prod

# AFTER
prometheus:
  prometheusSpec:
    remoteWrite:
      - url: http://mimir-nginx.mimir.svc.cluster.local/api/v1/push
        headers:
          X-Scope-OrgID: prod    # tenant ID
    externalLabels:
      cluster: prod
```

**`values-dev.yaml`** — dev cluster points to prod Mimir (cross-cluster):

```yaml
# The dev Prometheus needs to reach prod cluster Mimir.
# Options:
#   a) Expose Mimir via an internal ingress/service on your LAN
#   b) Use a ClusterIP + MetalLB LoadBalancer IP

prometheus:
  prometheusSpec:
    remoteWrite:
      - url: http://<mimir-metallb-ip>/api/v1/push   # or ingress URL
        headers:
          X-Scope-OrgID: dev    # separate tenant from prod
    externalLabels:
      cluster: dev
```

### 5. Remove Grafana Cloud from OTEL Collector

In `operators-helm/operators/otel-collector/values/chart/values-prd.yaml`, remove the `otlphttp/grafana` exporter and its references from all pipeline `exporters` lists:

```yaml
# Remove this entire block:
exporters:
  otlphttp/grafana:
    endpoint: https://otlp-gateway-prod-ca-east-0.grafana.net/otlp
    headers:
      authorization: "${env:GRAFANA_CLOUD_BASIC_AUTH_HEADER}"

# And remove otlphttp/grafana from:
service:
  pipelines:
    logs:
      exporters: [otlphttp/loki]       # was [otlphttp/loki, otlphttp/grafana]
    traces:
      exporters: [otlp/tempo]          # was [otlp/tempo, otlphttp/grafana]
```

You can also delete the `grafana-cloud-otel` ExternalSecret in the pre-resources.

### 6. Add Mimir as Grafana datasource

In `values-prd.yaml` under `grafana.additionalDataSources`, add:

```yaml
additionalDataSources:
  - name: Loki
    type: loki
    # ... existing ...

  - name: Mimir
    type: prometheus
    access: proxy
    url: http://mimir-nginx.mimir.svc.cluster.local/prometheus
    jsonData:
      httpHeaderName1: X-Scope-OrgID
    secureJsonData:
      httpHeaderValue1: "prod"    # query prod tenant by default

  - name: Mimir (dev)
    type: prometheus
    access: proxy
    url: http://mimir-nginx.mimir.svc.cluster.local/prometheus
    jsonData:
      httpHeaderName1: X-Scope-OrgID
    secureJsonData:
      httpHeaderValue1: "dev"     # query dev tenant
```

Also add Tempo as a datasource if not already there:

```yaml
  - name: Tempo
    type: tempo
    access: proxy
    url: http://tempo-helm.tempo.svc.cluster.local:3100
```

---

## Cleanup — Grafana Cloud credentials

Once Mimir is healthy, you can remove:

- `grafana-cloud-token` ExternalSecret in `kube-prometheus/pre-resources/`
- `grafana-cloud-otel` ExternalSecret in `otel-collector/pre-resources/`
- `GRAFANA_USERNAME`, `GRAFANA_CLOUD_BASIC_AUTH_HEADER` from Doppler

---

## Rollout Order (sync waves already handle most of this)

1. Apply Garage Mimir bucket Terraform Workspace (wave 17)
2. Deploy Mimir (wave 30 — same as Loki/Tempo)
3. Update OTEL Collector to remove Grafana Cloud exporters (wave 50)
4. Update kube-prometheus remoteWrite to point at Mimir (wave 40)
5. Update Grafana datasources to add Mimir (already in kube-prometheus values)
6. Verify metrics flow in Grafana → delete Grafana Cloud credentials from Doppler

---

## Optional Improvements

### Alertmanager in Mimir

Mimir has a built-in Alertmanager. You can migrate your Discord alert rules there and remove the dependency on kube-prometheus's Alertmanager for metrics-based alerts — keeping one Alertmanager for all signals.

### Recording Rules

Move expensive PromQL queries into Mimir recording rules so Grafana dashboards query pre-aggregated data. Useful once you have both dev and prod metrics flowing in.

### Retention Policy

Mimir's default retention is 30 days. Set per-tenant limits in the `limits` block:

```yaml
mimir:
  structuredConfig:
    limits:
      compactor_blocks_retention_period: 90d  # or whatever suits your Garage capacity
```

### Tempo Datasource + Exemplars

Wire Prometheus → Tempo exemplar linking in Grafana so you can jump from a metric spike directly to the trace that caused it. This requires `exemplar-storage` enabled in kube-prometheus:

```yaml
prometheus:
  prometheusSpec:
    enableFeatures:
      - exemplar-storage
```
