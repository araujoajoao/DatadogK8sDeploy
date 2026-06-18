# Appoena Observability Lab

Kubernetes lab deploying Java, Python and .NET apps on a local [kind](https://kind.sigs.k8s.io/) cluster with Datadog observability via **Single Step Instrumentation (SSI)** — zero manual instrumentation, just one agent CR.

## What it covers

- Local Kubernetes cluster with [kind](https://kind.sigs.k8s.io/)
- Datadog Agent + Cluster Agent managed by the Datadog Operator
- APM distributed tracing across Java → Python → .NET
- Log-trace correlation with `dd.trace_id` propagation
- Infrastructure metrics for Apache and RabbitMQ
- Datadog monitors and dashboard provisioned via shell script

## Architecture

- **Datadog resources** run in the `datadog` namespace
- **Infrastructure** (Apache, RabbitMQ) runs in `default`
- **Apps** (Java, Python, .NET) run in `apps` namespace and are auto-instrumented by SSI
- APM is disabled for `kube-system` and `default`

## Distributed Trace Flow

```
java-app /greeting
  └── python-app /api/dotnet
        └── dotnet-app /weatherforecast
```

Requests flow across languages with the same trace ID, visible in Datadog APM.

## Prerequisites

- [kind](https://kind.sigs.k8s.io/), kubectl, helm
- [Datadog account](https://app.datadoghq.com) with API Key and App Key
- `.env` file with your credentials

## Quick Start

For the full deployment commands, see [appoena-lab-deploy-guide.md](./appoena-lab-deploy-guide.md).

```bash
# Start the LoadBalancer controller
sudo cloud-provider-kind

# Create cluster
cat kubernetes/kind-config.yaml
kind create cluster --config kubernetes/kind-config.yaml --name appoena-lab

# Deploy
cat appoena-lab-deploy-guide.md  # follow step by step
```

## Teardown

```bash
./scripts/destroy-datadog-resources.sh
kind delete cluster --name appoena-lab
```

## Project Structure

- `kubernetes/` — cluster config and Datadog Agent CR
- `app/` — Apache and RabbitMQ workloads
- `builds/metrics/` — Java, Python and .NET apps with Services
- `configmap/` — logging and tracing ConfigMaps
- `scripts/` — deploy / destroy Datadog monitors and dashboard
- `terraform/` — legacy IaC alternative
