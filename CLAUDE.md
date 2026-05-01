# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Kubernetes observability project that deploys Java, .NET, and Python applications on a local KinD cluster with full Datadog integration (APM, logs, metrics, process monitoring).

## Cluster Lifecycle

```bash
# Create cluster
kind create cluster --config kubernetes/kind-config.yaml
kubectl apply -f https://docs.projectcalico.org/manifests/calico.yaml

# Store Datadog credentials as a secret (never commit real keys)
kubectl create secret generic datadog-secret \
  --from-literal=api-key=<YOUR_DATADOG_API_KEY> \
  --from-literal=app-key=<YOUR_DATADOG_APP_KEY>

# Install Datadog agent via Helm
helm repo add datadog https://helm.datadoghq.com && helm repo update
helm install datadog-agent -f kubernetes/datadog-values.yaml datadog/datadog --set agents.image.tag=7.36.0

# Destroy cluster
kind delete cluster --name datadog-cluster
```

## Deploying Applications

```bash
# Build images (source apps cloned separately from appoena/datadogpoweruser)
docker build -t java-app:latest builds/apps/java/
docker build -t dotnet-app:latest builds/apps/dotnet/
docker build -t python-app:latest builds/apps/python/

# Load into KinD (no registry needed for local dev)
kind load docker-image java-app:latest
kind load docker-image dotnet-app:latest
kind load docker-image python-app:latest

# Deploy middleware
kubectl apply -f app/apache-deployment.yaml
kubectl apply -f configmap/apache-configmap.yaml
kubectl apply -f app/rabbitmq-deployment.yaml
kubectl apply -f configmap/rabbitmq-configmap.yaml

# Deploy instrumented apps
kubectl apply -f builds/metrics/java-app.yaml
kubectl apply -f builds/metrics/dotnet-app.yaml
kubectl apply -f builds/metrics/python-app.yaml
```

## Verification

```bash
kubectl get pods
kubectl get pods | grep datadog
kubectl logs <datadog-agent-pod-name>
```

## Architecture

```
kubernetes/
  kind-config.yaml        — KinD cluster: 1 control-plane + 2 workers
  datadog-values.yaml     — Datadog Helm values (basic)
  datadog-values2.yaml    — Datadog Helm values with APM auto-instrumentation enabled

app/                      — Middleware deployments (Apache, RabbitMQ)
configmap/                — Datadog log collection ConfigMaps for middleware

builds/
  apps/{java,dotnet,python}/Dockerfile  — App images with DD tracer pre-installed
  metrics/{java,dotnet,python}-app.yaml — Kubernetes Deployments for instrumented apps
```

### Datadog Instrumentation Pattern

`builds/metrics/*.yaml` deployments use two mechanisms for APM:
1. **Admission webhook** (datadog-values2.yaml): Auto-injects tracer libs via `admission.datadoghq.com/enabled: "true"` + `admission.datadoghq.com/<lang>-lib.version` annotations.
2. **Manual Dockerfile injection** (builds/apps/*/Dockerfile): Tracers are baked into the image and activated via `DD_TRACE_ENABLED=true` + language-specific runner flags.

Pod labels `tags.datadoghq.com/{env,service,version}` map to Datadog unified service tagging. The `DD_API_KEY` is always read from the `datadog-secret` Kubernetes secret — never hardcoded in app manifests.

### Known Issues

- `builds/apps/python/Dockerfile` exposes port 8000 but `builds/metrics/python-app.yaml` targets port 5000 — align them when rebuilding.
- `builds/apps/dotnet/Dockerfile` has a typo: `DD_VERSION=1..0.0` (double dot).
- `kubernetes/datadog-values.yaml` and `datadog-values2.yaml` contain hardcoded API/app keys — use the Kubernetes secret pattern instead and keep those files out of commits with real credentials.
