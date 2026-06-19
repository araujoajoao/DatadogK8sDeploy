# ☸️🐶 Datadog Kubernetes Observability Lab

[![Validate](https://github.com/araujoajoao/DatadogK8sDeploy/actions/workflows/validate.yml/badge.svg)](https://github.com/araujoajoao/DatadogK8sDeploy/actions/workflows/validate.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Terraform](https://img.shields.io/badge/terraform-%235835CC.svg?style=flat&logo=terraform&logoColor=white)](https://www.terraform.io/)
[![Kubernetes](https://img.shields.io/badge/kubernetes-%23326ce5.svg?style=flat&logo=kubernetes&logoColor=white)](https://kubernetes.io/)

> Kubernetes lab deploying 3 polyglot services on a local [kind](https://kind.sigs.k8s.io/) cluster with **Datadog observability** via **Single Step Instrumentation (SSI)** — zero manual instrumentation, just one agent CR.

## 🎯 Why This Lab?

Learn production-grade observability patterns in **under 30 minutes** on a **completely free** local cluster:

- ☸️ **Multi-language APM** — distributed traces across Java, Python, and .NET
- 📝 **Log-trace correlation** — see `dd.trace_id` injected automatically into every log line
- 📊 **Infrastructure + APM in one view** — Apache and RabbitMQ metrics alongside application traces
- 🔔 **Alerting as code** — Datadog monitors and dashboards managed with Terraform
- ⚡ **Zero instrumentation** — Datadog SSI injects tracing libraries automatically at admission time

## 🚀 TL;DR Quick Start

```bash
# 1. Start the LoadBalancer controller (keep running)
sudo cloud-provider-kind

# 2. Clone and deploy
git clone https://github.com/araujoajoao/DatadogK8sDeploy.git
cd DatadogK8sDeploy
cp .env.example .env
# Edit .env with your real Datadog API and App keys
source .env

# 3. Spin up the cluster and everything inside it
kind create cluster --config kubernetes/kind-config.yaml --name datadog-k8s-lab
kubectl create secret generic datadog-secret \
  --from-literal=api-key="$DATADOG_API_KEY" \
  --from-literal=app-key="$DATADOG_APP_KEY" \
  -n datadog
kubectl apply -f kubernetes/datadog-agent.yaml
kubectl apply -f configmap/ -f app/ -f builds/metrics/

# 4. Deploy Datadog resources via Terraform
cd terraform
terraform init && terraform apply

# 5. Generate traffic
./populate.sh
```

> 📖 For the full step-by-step guide with explanations, see [deploy-guide.md](./deploy-guide.md).

## What it covers

- ☸️ Local Kubernetes cluster with [kind](https://kind.sigs.k8s.io/)
- 🐶 Datadog Agent + Cluster Agent managed by the Datadog Operator
- 🔗 APM distributed tracing across a 3-tier polyglot service chain
- 📝 Log-trace correlation with `dd.trace_id` propagation
- 📊 Infrastructure metrics for proxy and messaging workloads
- 🔔 Datadog monitors and dashboard provisioned via Terraform

## Architecture

- 🐶 **Datadog resources** run in the `datadog` namespace
- 🏗️ **Infrastructure** (proxy, message broker) runs in `default`
- ⚙️ **Services** (frontend, middleware, backend) run in `apps` namespace and are auto-instrumented by SSI
- 🚫 APM is disabled for `kube-system` and `default`

## Distributed Trace Flow

```
frontend-service /greeting
  └── middleware-service /api/backend
        └── backend-service /data
```

Requests flow across 3 different languages with the same trace ID, visible in Datadog APM.

## Prerequisites

- 🛠️ [kind](https://kind.sigs.k8s.io/), kubectl, helm
- 🔑 [Datadog account](https://app.datadoghq.com) with API Key and App Key
- 📄 `.env` file with your credentials

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

- ☸️ `kubernetes/` — cluster config and Datadog Agent CR
- 🏗️ `app/` — infrastructure workloads (proxy, message broker)
- 📦 `builds/metrics/` — polyglot services (frontend, middleware, backend) plus Services
- 🗂️ `configmap/` — logging and tracing patches
- ⏳ `deprecated/shell-scripts/` — legacy shell scripts for deploy / destroy (deprecated; use Terraform)
- 🔧 `terraform/` — Datadog monitors and dashboard via Terraform

## Contributing

We welcome contributions! See [CONTRIBUTING.md](./CONTRIBUTING.md) for guidelines.

## License

[MIT License](./LICENSE)
