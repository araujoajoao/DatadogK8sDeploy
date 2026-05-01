# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Kubernetes observability project that deploys Java, .NET, and Python applications on a local KinD cluster with full Datadog integration (APM traces, logs, metrics) using the **Datadog Operator**.

## Cluster Lifecycle

```bash
# Create cluster
kind create cluster --config kubernetes/kind-config.yaml
kubectl apply -f https://docs.projectcalico.org/manifests/calico.yaml

# Create Datadog credentials secret (never commit real keys)
kubectl create secret generic datadog-secret \
  --from-literal=api-key=<YOUR_DATADOG_API_KEY> \
  --from-literal=app-key=<YOUR_DATADOG_APP_KEY>

# Install Datadog Operator
helm repo add datadog https://helm.datadoghq.com && helm repo update
helm install datadog-operator datadog/datadog-operator
kubectl wait pod --selector=app.kubernetes.io/name=datadog-operator \
  --for=condition=Ready --timeout=60s

# Deploy Datadog Agent via the Operator CR
kubectl apply -f kubernetes/datadog-agent.yaml

# Destroy cluster
kind delete cluster --name datadog-cluster
```

## Deploying Applications

```bash
# Deploy middleware
kubectl apply -f app/apache-deployment.yaml
kubectl apply -f app/rabbitmq-deployment.yaml
kubectl apply -f configmap/apache-configmap.yaml
kubectl apply -f configmap/rabbitmq-configmap.yaml

# Deploy instrumented apps (images pulled from Docker Hub: araujoajoao/*)
kubectl apply -f builds/metrics/java-app.yaml
kubectl apply -f builds/metrics/dotnet-app.yaml
kubectl apply -f builds/metrics/python-app.yaml
```

## Verification

```bash
kubectl get datadogagent datadog
kubectl get pods
kubectl logs -l app.kubernetes.io/component=agent -c agent --tail=50
kubectl describe datadogagent datadog
```

## Architecture

```
kubernetes/
  kind-config.yaml       — KinD cluster: 1 control-plane + 2 workers
  datadog-agent.yaml     — DatadogAgent CR (v2alpha1) — single source of truth for agent config
  datadog-secret.yaml    — Kubernetes Secret with API/App keys (gitignored, do not commit)

app/                     — Middleware deployments (Apache, RabbitMQ)
configmap/               — Datadog file-based log config (supplementary; container logs use annotations)

builds/metrics/          — Kubernetes Deployments for instrumented apps (Java, .NET, Python)
```

## Datadog Instrumentation Pattern

### Agent (DatadogAgent CR)
`kubernetes/datadog-agent.yaml` uses the `datadoghq.com/v2alpha1` API. Key features enabled:
- **Logs**: `logCollection.containerCollectAll: true` — collects all container stdout/stderr
- **APM**: `apm.hostPortConfig.enabled: true` on port 8126 — receives traces from app pods
- **Metrics**: `kubeStateMetricsCore`, `processDiscovery`, `orchestratorExplorer`
- **Admission controller**: enabled for future auto-injection of `DD_AGENT_HOST`

### Apps (builds/metrics/*.yaml)
Each deployment has three instrumentation layers:
1. **Unified service tagging** — `tags.datadoghq.com/{env,service,version}` on both `metadata.labels` and `spec.template.metadata.labels`
2. **APM** — `DD_AGENT_HOST` via downward API (`status.hostIP`) + `DD_TRACE_AGENT_PORT: "8126"` directs traces to the DaemonSet agent on the same node
3. **Log correlation** — `DD_LOGS_INJECTION: "true"` injects trace IDs into app logs; `ad.datadoghq.com/<name>.logs` annotation sets the source/service for the Datadog agent's log collector

### Middleware (app/*.yaml)
Apache and RabbitMQ use auto-discovery annotations for both logs and metrics checks:
- `ad.datadoghq.com/apache.logs` / `ad.datadoghq.com/rabbitmq.logs` — log source tagging
- `ad.datadoghq.com/apache.checks` — Apache HTTP server status metric collection
- `ad.datadoghq.com/rabbitmq.checks` — RabbitMQ management API metric collection (guest/guest)

### Security Note
`kubernetes/datadog-secret.yaml` is gitignored. Always create the secret with `kubectl create secret` and never commit real credentials.
