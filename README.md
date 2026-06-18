# Appoena Observability Lab — k8s-datadog

Kubernetes observability lab running Java, Python, and .NET applications on a local [kind](https://kind.sigs.k8s.io/) cluster with full Datadog integration via the **Datadog Operator** and **Single Step Instrumentation (SSI)**.

## What this lab covers

- Kubernetes cluster with kind (1 control-plane + 3 workers, linux/arm64)
- Datadog Operator v1.26 managing the agent DaemonSet and Cluster Agent
- APM with **Single Step Instrumentation** — no manual init containers, no ddtrace-run
- Distributed tracing across Java → Python → .NET
- Log-trace correlation with real `dd.trace_id` propagation in all three apps
- JSON structured logs with multiline rules at the agent level
- Infrastructure metrics: Apache, RabbitMQ, Kubernetes, JVM/runtime
- Monitors and dashboard provisioned via shell script or Terraform

## Stack

| Component | Image / Version |
|---|---|
| Datadog Agent | `7.80.0` |
| Datadog Cluster Agent | `7.80.0` |
| Java app | `araujoajoao/java-app:latest` (Spring Boot, port 8080) |
| Python app | `araujoajoao/python-app:py311` (Flask, Python 3.11, port 5000) |
| .NET app | `araujoajoao/dotnet-app:latest` (ASP.NET Core, port 80) |
| Apache | `httpd:latest` |
| RabbitMQ | `rabbitmq:management` |

## Namespace Layout

| Namespace | What lives here |
|---|---|
| `default` | Datadog agent DaemonSet, Cluster Agent, Apache, RabbitMQ |
| `apps` | java-app, python-app, dotnet-app and their Services |

SSI is disabled for `kube-system` and `default` — **apps must be in the `apps` namespace** to receive automatic instrumentation.

## APM — Single Step Instrumentation

All three apps are instrumented by the Datadog Admission Controller automatically. Each pod carries a language annotation (not a label):

```yaml
annotations:
  admission.datadoghq.com/java-lib.version: "latest"     # java-app
  admission.datadoghq.com/python-lib.version: "latest"   # python-app
  admission.datadoghq.com/dotnet-lib.version: "latest"   # dotnet-app
```

The SSI feature is declared in `kubernetes/datadog-agent.yaml`:

```yaml
features:
  apm:
    instrumentation:
      enabled: true
      disabledNamespaces:
        - kube-system
        - default
```

**Python note:** The python image has `ddtrace` pre-installed, which causes SSI's `sitecustomize.py` to abort its own injection. Log injection is enabled manually by importing `ddtrace.bootstrap.sitecustomize` at the top of `configmap/python-logging-patch.yaml`.

## Distributed Trace Flow

```
java-app GET /greeting
  └── calls http://python-flask:8082/api/dotnet   (same trace_id propagated)
        └── python-app GET /api/dotnet
              └── calls http://dotnet-app/weatherforecast   (trace continues)
                    └── dotnet-app GET /weatherforecast
```

`python-flask` is a ClusterIP alias Service in the `apps` namespace that routes to the `python-app` pods on ports 80, 5000, and 8082 (the port hardcoded in the Java app's `GreetingController`).

## Traffic Endpoints

Apps expose LoadBalancer IPs via `cloud-provider-kind`. Run `sudo cloud-provider-kind` in a dedicated terminal before deploying.

| App | LoadBalancer | Endpoint |
|---|---|---|
| java-app | `192.168.97.8:8080` | `/greeting` |
| python-app | `192.168.97.6:5000` | `/` and `/api/dotnet` |
| dotnet-app | `192.168.97.7:80` | `/weatherforecast` |

IPs may differ on your machine — check with `kubectl get svc -n apps`.

> **Generate traffic automatically:** After deployment, run `./populate.sh` to send requests to all endpoints and trigger distributed traces in Datadog.

## Log-Trace Correlation

| App | Format | Trace field |
|---|---|---|
| Java | JSON via Logback pattern | `dd.trace_id` (dot) |
| Python | JSON via custom `DDJsonFormatter` | `dd.trace_id` (dot) |
| .NET | JSON via Serilog + Datadog sink | `dd_trace_id` (underscore, correct for .NET) |

Multiline JSON aggregation rules are configured **at the agent level** via `extraConfd.configDataMap` in `kubernetes/datadog-agent.yaml` — not in the application pods.

## Quick Start

See [appoena-lab-deploy-guide.md](./appoena-lab-deploy-guide.md) for the full validated step-by-step guide.

### Prerequisites

```bash
brew install kind kubectl helm terraform
brew install cloud-provider-kind   # required for LoadBalancer IPs on kind
```

You also need a [Datadog account](https://app.datadoghq.com) with an API Key and App Key.

Set up your `.env` file with your credentials:

```bash
# Edit .env with your real DATADOG_API_KEY and DATADOG_APP_KEY
source .env
```

### Deploy

```bash
# 0. Start LoadBalancer controller (keep this terminal open)
sudo cloud-provider-kind

# 1. Create the cluster
kind create cluster --config kubernetes/kind-config.yaml --name appoena-lab

# 2. Install the Datadog Operator
helm repo add datadog https://helm.datadoghq.com && helm repo update
helm install datadog-operator datadog/datadog-operator --namespace datadog --create-namespace

# 3. Create the Datadog secret from .env
source .env
kubectl create secret generic datadog-secret \
  --from-literal=api-key="$DATADOG_API_KEY" \
  --from-literal=app-key="$DATADOG_APP_KEY" \
  -n datadog

> Do not apply `kubernetes/datadog-secret.yaml` directly — it contains placeholder values only.

# 4. Deploy the Datadog Agent
kubectl apply -f kubernetes/datadog-agent.yaml

# 5. Deploy ConfigMaps (default namespace — for apache/rabbitmq in default)
kubectl apply -f configmap/apache-configmap.yaml
kubectl apply -f configmap/rabbitmq-configmap.yaml

# 6. Create apps namespace and deploy app ConfigMaps
kubectl create namespace apps
kubectl apply -f configmap/java-logging-config.yaml
kubectl apply -f configmap/python-logging-patch.yaml

# 7. Deploy Apache and RabbitMQ
kubectl apply -f app/

# 8. Deploy apps and services
kubectl apply -f builds/metrics/

# 9. Provision Datadog monitors and dashboard
#
# Option A — Shell script (recommended, no Terraform)
# Ensure .env is sourced (keys are read automatically by the scripts)
./scripts/deploy-datadog-resources.sh
#
# Option B — Terraform (legacy)
# cd terraform && terraform init
# terraform apply \
#   -var="datadog_api_key=${DATADOG_API_KEY}" \
#   -var="datadog_app_key=${DATADOG_APP_KEY}"
```

## Repository Structure

```
kubernetes/
  kind-config.yaml          # Cluster: 1 control-plane + 3 workers
  datadog-agent.yaml        # DatadogAgent CR (v2alpha1) — all features + extraConfd log rules
  datadog-secret.yaml       # Template only — create secret via kubectl, never apply this file

app/
  apache-deployment.yaml    # Apache with mod_status init container (default namespace)
  apache-service.yaml       # ClusterIP port 80
  rabbitmq-deployment.yaml  # RabbitMQ management, stdout logging (default namespace)
  rabbitmq-service.yaml     # ClusterIP ports 5672 + 15672

configmap/
  apache-configmap.yaml     # Reference only — checks/logs driven by pod annotations
  rabbitmq-configmap.yaml   # Reference only — checks/logs driven by pod annotations
  java-logging-config.yaml  # Logback JSON pattern with dd.trace_id (apps namespace)
  python-logging-patch.yaml # Flask entrypoint: ddtrace bootstrap + DDJsonFormatter + /api/dotnet route (apps namespace)

builds/metrics/
  java-app.yaml             # Spring Boot — SSI annotation, port 8080, LoadBalancer
  python-app.yaml           # Flask py311 — SSI annotation, port 5000, LoadBalancer
  dotnet-app.yaml           # ASP.NET Core — SSI annotation, port 80, LoadBalancer
  services.yaml             # All app Services including python-flask alias (ports 80/5000/8082)

scripts/
  deploy-datadog-resources.sh   # Creates Datadog monitors + dashboard via API (no Terraform)
  destroy-datadog-resources.sh  # Deletes Datadog monitors + dashboard via API

terraform/
  providers.tf              # Datadog provider ~3.0
  variables.tf              # api_key, app_key, notification_email, env
  monitors.tf               # Pod memory alert + CrashLoopBackOff monitor
  dashboard.tf              # Application Error Dashboard
```

## Datadog UI

| What | Where | Filter |
|---|---|---|
| Cluster | Infrastructure → Kubernetes | `cluster:appoena-lab` |
| APM / Distributed Traces | APM → Traces | `env:mentoria` |
| Services | APM → Services | `env:mentoria` |
| Logs | Logs → Explorer | `service:(java-app OR python-app OR dotnet-app OR apache OR rabbitmq) env:mentoria` |
| Monitors | Monitors → Manage | `[mentoria]` |
| Dashboard | Dashboards → List | `Application Error Dashboard` |

## Teardown

```bash
# Destroy Datadog monitors and dashboard (shell script — recommended)
./scripts/destroy-datadog-resources.sh

# Delete the kind cluster
kind delete cluster --name appoena-lab

# Alternatively — Terraform teardown (legacy)
# cd terraform && terraform destroy \
#   -var="datadog_api_key=${DATADOG_API_KEY}" \
#   -var="datadog_app_key=${DATADOG_APP_KEY}"
```
