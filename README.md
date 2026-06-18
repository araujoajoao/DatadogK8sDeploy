# Appoena Observability Lab — k8s-datadog

Kubernetes observability lab running Java, Python, and .NET applications on a local [kind](https://kind.sigs.k8s.io/) cluster with full Datadog integration via the **Datadog Operator** and **Single Step Instrumentation (SSI)**.

## What this lab covers

- Kubernetes cluster with kind (1 control-plane + 3 workers, linux/arm64)
- Datadog Operator managing the agent DaemonSet and Cluster Agent
- APM with **Single Step Instrumentation** — no manual init containers, no `ddtrace-run`
- Distributed tracing across Java → Python → .NET
- Log-trace correlation with real `dd.trace_id` propagation in all three apps
- JSON structured logs with multiline rules at the agent level
- Infrastructure metrics: Apache, RabbitMQ, Kubernetes, JVM/runtime
- Monitors and dashboard provisioned via shell script

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
| `datadog` | Datadog agent DaemonSet, Cluster Agent, Operator |
| `default` | Apache, RabbitMQ (infrastructure) |
| `apps` | java-app, python-app, dotnet-app and their Services |

SSI is disabled for `kube-system` and `default` — **apps must be in the `apps` namespace** to receive automatic instrumentation.

## APM — Single Step Instrumentation

All three apps are instrumented by the Datadog Admission Controller automatically. Each pod carries a language annotation:

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
  └── calls http://python-flask:8082/api/dotnet
        └── python-app GET /api/dotnet
              └── calls http://dotnet-app/weatherforecast
                    └── dotnet-app GET /weatherforecast
```

`python-flask` is a ClusterIP alias Service in the `apps` namespace that routes to the `python-app` pods on ports 80, 5000, and 8082 (the port hardcoded in the Java app's `GreetingController`).

## Traffic Endpoints

Apps expose LoadBalancer IPs via `cloud-provider-kind`.

| App | LoadBalancer | Endpoint |
|---|---|---|
| java-app | `192.168.97.8:8080` | `/greeting` |
| python-app | `192.168.97.6:5000` | `/` and `/api/dotnet` |
| dotnet-app | `192.168.97.7:80` | `/weatherforecast` |

> After deployment, run `./populate.sh` to send requests to all endpoints and trigger distributed traces in Datadog.

## Log-Trace Correlation

| App | Format | Trace field |
|---|---|---|
| Java | JSON via Logback pattern | `dd.trace_id` (dot) |
| Python | JSON via custom `DDJsonFormatter` | `dd.trace_id` (dot) |
| .NET | JSON via Serilog + Datadog sink | `dd_trace_id` (underscore, correct for .NET) |

Multiline JSON aggregation rules are configured **at the agent level** via `extraConfd.configDataMap` in `kubernetes/datadog-agent.yaml`.

## Repository Structure

```
kubernetes/
  kind-config.yaml          # Cluster: 1 control-plane + 3 workers, linux/arm64
  datadog-agent.yaml        # DatadogAgent CR (v2alpha1) — agent 7.80.0, SSI, extraConfd log rules

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
  deploy-datadog-resources.sh   # Creates Datadog monitors + dashboard via API
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

## Getting Started

See [appoena-lab-deploy-guide.md](./appoena-lab-deploy-guide.md) for the full step-by-step deployment guide.

### Prerequisites

- [kind](https://kind.sigs.k8s.io/), kubectl, helm
- [Datadog account](https://app.datadoghq.com) with API Key and App Key
- A `.env` file with your credentials (copy from `.env.example`)

### Deploy

See [appoena-lab-deploy-guide.md](./appoena-lab-deploy-guide.md) for the full step-by-step deployment commands.

```bash
# Quick reference — see deploy guide for full commands
sudo cloud-provider-kind
kind create cluster --config kubernetes/kind-config.yaml --name appoena-lab
# ... then follow appoena-lab-deploy-guide.md
```

### Teardown

```bash
./scripts/destroy-datadog-resources.sh
kind delete cluster --name appoena-lab
```
