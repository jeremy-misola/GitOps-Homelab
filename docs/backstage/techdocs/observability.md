# Observability Stack

A comprehensive observability stack built on the **LGTM** (Loki, Grafana, Tempo, Prometheus) framework with **OpenTelemetry** as the unified telemetry pipeline.

## Architecture Overview

![Observability Architecture](../images/observability.svg)

## Components

### Telemetry Pipeline

| Component | Role | Configuration Highlights |
| :--- | :--- | :--- |
| **OpenTelemetry Collector** | Unified telemetry ingestion | DaemonSet mode, OTLP (gRPC/HTTP), K8s attributes enrichment, batch processing |
| **Prometheus** | Metrics collection | Kube-Prometheus Stack with Alertmanager, ServiceMonitor CRDs |
| **Loki** | Log aggregation | TSDB schema v13, S3 backend (Garage), OTLP ingestion via gateway |
| **Tempo** | Distributed tracing | Backend for OpenTelemetry traces, gRPC receiver |
| **Blackbox Exporter** | Endpoint probing | HTTP probes for external services (ArgoCD) |
| **Grafana** | Unified visualization | Single pane of glass for metrics, logs, and traces |

## Data Flow

### Metrics Pipeline
```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│  K8s Pods   │────▶│ Prometheus  │────▶│   Grafana   │
│  Services   │     │  (scrape)   │     │ (visualize) │
└─────────────┘     └─────────────┘     └─────────────┘
```

1. Prometheus scrapes metrics from K8s components and Envoy proxies via `ServiceMonitor` CRDs
2. Alertmanager handles alerting rules and notifications

### Logs Pipeline
```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│  Pod Logs   │────▶│   OTEL      │────▶│    Loki     │────▶│   Grafana   │
│ /var/log    │     │  Collector  │     │  (storage)  │     │ (query)     │
└─────────────┘     └─────────────┘     └─────────────┘     └─────────────┘
```

1. OpenTelemetry Collector reads from `/var/log/pods`
2. Enriches with K8s metadata
3. Pushes to Loki via OTLP

### Traces Pipeline
```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│Application  │────▶│   OTEL      │────▶│    Tempo    │────▶│   Grafana   │
│ (spans)     │     │  Collector  │     │  (storage)  │     │ (query)     │
└─────────────┘     └─────────────┘     └─────────────┘     └─────────────┘
```

1. Microservices auto-instrumented with Java agent emit spans to Otel Collector
2. Tempo stores traces
3. Grafana queries for correlation

## Key Features

### Zero-Code Instrumentation
Java microservices automatically instrumented via OpenTelemetry Operator's `Instrumentation` CRD. No code changes required.

### S3-Backed Storage
Loki uses Garage S3 for scalable, cost-effective log retention. This provides:
- Durable long-term storage
- Cost-effective log retention
- Scalable architecture

### Uptime Monitoring
Blackbox Exporter probes external endpoints and exposes availability metrics to Prometheus:
- HTTP probes for external services (ArgoCD, Ghost, etc.)
- SSL certificate expiry monitoring
- Response time metrics

### Correlated Debugging
Trace IDs from Tempo can be cross-referenced with logs in Loki through Grafana's Explore view:
1. Identify slow requests in traces
2. Jump to related logs via trace ID
3. Correlate metrics during the same time window

### Data Durability
Automated volume backups are replicated to off-site S3 storage via Longhorn's recurring job system.

## Access

| Service | URL | Purpose |
|---------|-----|---------|
| Grafana | https://grafana.jeremymr.dev | Unified observability dashboard |
| Prometheus | Internal | Metrics collection and alerting |
| Loki | Internal | Log aggregation |
| Tempo | Internal | Distributed tracing |

## Configuration Files

- OpenTelemetry Collector: `argocd-apps/infrastructure/opentelemetry-collector/`
- Loki: `argocd-apps/infrastructure/loki/`
- Tempo: `argocd-apps/infrastructure/tempo/`
- Prometheus Stack: `argocd-apps/infrastructure/monitoring/`