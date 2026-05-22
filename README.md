# Appoena Observability Lab — k8s-datadog

Kubernetes observability lab deploying Java, Python, and .NET applications on a local [kind](https://kind.sigs.k8s.io/) cluster with full Datadog integration via the **Datadog Operator**.

## What this lab covers

- Kubernetes cluster with kind (1 control-plane + 3 workers)
- Datadog Operator managing the agent DaemonSet and Cluster Agent
- APM traces with automatic instrumentation for Java, Python, and .NET
- Log collection with unified service tagging (`env:mentoria`)
- Infrastructure metrics: Apache, RabbitMQ, Kubernetes, JVM/runtime
- Monitors and dashboard provisioned via Terraform

## Stack

| Component | Image / Version |
|---|---|
| Datadog Agent | `7.79.0` |
| Datadog Cluster Agent | `7.79.0` |
| Java app | `araujoajoao/java-app:latest` (Spring Boot) |
| Python app | `araujoajoao/python-app:latest` (Flask) |
| .NET app | `araujoajoao/dotnet-app:latest` (ASP.NET Core) |
| Apache | `httpd:latest` |
| RabbitMQ | `rabbitmq:management` |

## APM Instrumentation

Each app uses the Datadog init-container pattern (manual library injection via `emptyDir` volume) with the following validated configuration:

| App | Language | Method | Init image |
|---|---|---|---|
| java-app | Spring Boot | `JAVA_TOOL_OPTIONS=-javaagent:/datadog-lib/package/dd-java-agent.jar` | `dd-lib-java-init` |
| python-app | Flask | `command: ["ddtrace-run", "python", "app.py"]` — required because ddtrace is pre-installed in the image; the init container's `sitecustomize.py` detects it and aborts if `ddtrace-run` is not used | `dd-lib-python-init` |
| dotnet-app | ASP.NET Core | `CORECLR_PROFILER_PATH=/datadog-lib/package/Datadog.Trace.ClrProfiler.Native.so` and `DD_DOTNET_TRACER_HOME=/datadog-lib/package` — files land in the `package/` subdirectory, not the root | `dd-lib-dotnet-init` |

**Traffic endpoints for APM trace generation:**

| App | Endpoint | Port |
|---|---|---|
| java-app | `/greeting` | 8080 |
| python-app | `/` | 5000 |
| dotnet-app | `/weatherforecast` | 80 |

## Quick start

See [appoena-lab-deploy-guide.md](./appoena-lab-deploy-guide.md) for the full validated step-by-step guide.

### Prerequisites

```bash
brew install kind kubectl helm terraform
```

You also need a [Datadog trial account](https://app.datadoghq.com) with an API Key and an App Key.

### Deploy

```bash
# 1. Create the cluster
kind create cluster --config kubernetes/kind-config.yaml --name appoena-lab

# 2. Install the Datadog Operator
helm repo add datadog https://helm.datadoghq.com && helm repo update
helm install datadog-operator datadog/datadog-operator --namespace default

# 3. Create the Datadog secret
kubectl create secret generic datadog-secret \
  --from-literal=api-key=YOUR_API_KEY \
  --from-literal=app-key=YOUR_APP_KEY

# 4. Deploy the Datadog Agent
kubectl apply -f kubernetes/datadog-agent.yaml

# 5. Deploy ConfigMaps, middleware, and apps
kubectl apply -f configmap/
kubectl apply -f app/
kubectl apply -f builds/metrics/

# 6. Provision monitors and dashboard (Terraform)
cd terraform && terraform init
terraform apply -var="datadog_api_key=YOUR_API_KEY" -var="datadog_app_key=YOUR_APP_KEY"
```

## Repository structure

```
kubernetes/
  kind-config.yaml        # Cluster: 1 control-plane + 3 workers
  datadog-agent.yaml      # DatadogAgent CR (v2alpha1) — agent + all features

app/
  apache-deployment.yaml  # Apache with mod_status init container
  apache-service.yaml
  rabbitmq-deployment.yaml
  rabbitmq-service.yaml

configmap/
  apache-configmap.yaml   # Apache log paths + check instances
  rabbitmq-configmap.yaml # RabbitMQ log paths + check instances

builds/metrics/
  java-app.yaml           # Spring Boot — APM + logs, port 8080
  python-app.yaml         # Flask — APM + logs, port 5000
  dotnet-app.yaml         # ASP.NET Core — APM + logs, port 80

terraform/
  providers.tf
  variables.tf
  monitors.tf             # Memory alert + CrashLoopBackOff monitor
  dashboard.tf            # Application Error Dashboard
```

## Datadog UI

| What | Where | Filter |
|---|---|---|
| Cluster | Infrastructure → Kubernetes | `cluster:appoena-lab` |
| APM | APM → Services | `env:mentoria` |
| Logs | Logs → Explorer | `service:(apache OR rabbitmq OR java-app OR python-app OR dotnet-app) env:mentoria` |
| Monitors | Monitors → Manage | `[mentoria]` |
| Dashboard | Dashboards → List | `Application Error Dashboard` |

## Teardown

```bash
cd terraform && terraform destroy \
  -var="datadog_api_key=YOUR_API_KEY" \
  -var="datadog_app_key=YOUR_APP_KEY"

kind delete cluster --name appoena-lab
```
