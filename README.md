# Datadog Kubernetes Observability Lab

Kubernetes lab deploying 3 polyglot services on a local [kind](https://kind.sigs.k8s.io/) cluster with Datadog observability via **Single Step Instrumentation (SSI)** — zero manual instrumentation, just one agent CR.

## What it covers

- Local Kubernetes cluster with [kind](https://kind.sigs.k8s.io/)
- Datadog Agent + Cluster Agent managed by the Datadog Operator
- APM distributed tracing across a 3-tier polyglot service chain
- Log-trace correlation with `dd.trace_id` propagation
- Infrastructure metrics for proxy and messaging workloads
- Datadog monitors and dashboard provisioned via Terraform

## Architecture

- **Datadog resources** run in the `datadog` namespace
- **Infrastructure** (proxy, message broker) runs in `default`
- **Services** (frontend, middleware, backend) run in `apps` namespace and are auto-instrumented by SSI
- APM is disabled for `kube-system` and `default`

## Distributed Trace Flow

```
frontend-service /greeting
  └── middleware-service /api/backend
        └── backend-service /data
```

Requests flow across 3 different languages with the same trace ID, visible in Datadog APM.

## Prerequisites

- [kind](https://kind.sigs.k8s.io/), kubectl, helm
- [Datadog account](https://app.datadoghq.com) with API Key and App Key
- `.env` file with your credentials

## Quick Start

For the full deployment commands, see [deploy-guide.md](./deploy-guide.md).

```bash
# Start the LoadBalancer controller
sudo cloud-provider-kind

# Create cluster
cat kubernetes/kind-config.yaml
kind create cluster --config kubernetes/kind-config.yaml --name datadog-k8s-lab

# Deploy
cat deploy-guide.md  # follow step by step
```

## Teardown

```bash
cd terraform && terraform destroy
kind delete cluster --name datadog-k8s-lab
```

## Project Structure

- `kubernetes/` — cluster config and Datadog Agent CR
- `app/` — infrastructure workloads (proxy, message broker)
- `builds/metrics/` — polyglot services (frontend, middleware, backend) plus Services
- `configmap/` — logging and tracing patches
- `deprecated/shell-scripts/` — legacy shell scripts for deploy / destroy (deprecated; use Terraform)
- `terraform/` — Datadog monitors and dashboard via Terraform
