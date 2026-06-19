# Datadog Kubernetes Observability Lab — Deploy Guide

Step-by-step commands to deploy the full stack from scratch.

> 💡 **First time?** Don't worry if these terms are new. Every tool and command is explained below. Just copy each block and paste it into your terminal. If a command fails, check the **Known Issues** section at the bottom.

## Prerequisites

```bash
brew install kind kubectl helm terraform
brew install cloud-provider-kind
```

Verify:

```bash
kind version && kubectl version --client && helm version && terraform version
```

You need:
- 🐶 A Datadog account at [app.datadoghq.com](https://app.datadoghq.com)
- 🔑 API Key and App Key from **Organization Settings**
- 📄 A `.env` file with real credentials (copy from `.env.example`)

Set up `.env` before running any scripts:

```bash
# Edit .env with your real DATADOG_API_KEY and DATADOG_APP_KEY
source .env
```

---

## Step 0 — Start the LoadBalancer Controller

> **What this does:** `kind` clusters can't expose services to the outside world by default. This helper creates fake LoadBalancer IPs so you can access your apps from your browser/curl.
>
> 💡 **Beginner tip:** This must run in its own terminal window and stay open while the cluster is running.

Keep running in a dedicated terminal:

```bash
sudo cloud-provider-kind
```

---

## Step 1 — Create the kind Cluster

> **What this does:** Spins up a virtual Kubernetes cluster inside Docker containers on your laptop. This is completely free and takes ~2 minutes.
>
> 💡 **Beginner tip:** We use `kind` because it's the fastest way to get a real Kubernetes cluster locally without needing cloud credentials.

```bash
kind create cluster --config kubernetes/kind-config.yaml --name datadog-k8s-lab
```

If this succeeds, you should see `Creating cluster "datadog-k8s-lab" ...` and eventually `Ready`.

Verify nodes:

```bash
kubectl get nodes
```

---

## Step 2 — Install the Datadog Operator

> **What this does:** The Datadog Operator is a Kubernetes controller that automatically installs and manages the Datadog Agent on every node. Think of it as "the Datadog sysadmin for your cluster."
>
> 💡 **Beginner tip:** An **Operator** is a Kubernetes app that manages other apps. We use one because it handles all the hard Datadog setup automatically.

```bash
helm repo add datadog https://helm.datadoghq.com
helm repo update
helm install datadog-operator datadog/datadog-operator --namespace datadog --create-namespace
```

Wait for rollout (this means "wait until the Operator pod is running"):

```bash
kubectl rollout status deployment/datadog-operator -n datadog
```

---

## Step 3 — Create the Datadog Secret

> **What this does:** A Kubernetes **Secret** safely stores sensitive data (your Datadog API keys) inside the cluster. The Datadog Agent reads this Secret to authenticate with Datadog's servers.
>
> 💡 **Beginner tip:** Never hardcode passwords in YAML files. Secrets keep them encrypted in the cluster.

```bash
source .env
kubectl create secret generic datadog-secret \
  --from-literal=api-key="$DATADOG_API_KEY" \
  --from-literal=app-key="$DATADOG_APP_KEY" \
  -n datadog
```

> ⚠️ Do not apply `kubernetes/datadog-secret.yaml` directly — it contains placeholder values only.

---

## Step 4 — Deploy the Datadog Agent

> **What this does:** The Datadog Agent is the "watchman" that runs on every machine in your cluster. It collects **metrics**, **logs**, and **traces** from everything running nearby and sends them to Datadog.
>
> 💡 **Beginner tip:** The Agent has two parts: (1) a **DaemonSet** that runs on every node, and (2) a **Cluster Agent** that watches the whole cluster.

```bash
kubectl apply -f kubernetes/datadog-agent.yaml
```

Wait for rollouts (this means "wait until the pods are ready"):

```bash
kubectl rollout status daemonset/datadog-agent -n datadog
kubectl rollout status deployment/datadog-cluster-agent -n datadog
```

Check Datadog UI: **Infrastructure → Kubernetes**, cluster `datadog-k8s-lab` — appears in 2–3 minutes.

> 💡 **Beginner tip:** Don't worry if it takes a few minutes. The Agent needs to start, discover your cluster, and send its first batch of data to Datadog's servers.

---

## Step 5 — Deploy Infrastructure ConfigMaps

> **What this does:** A **ConfigMap** is a Kubernetes way to store configuration files (like `httpd.conf` or `rabbitmq.yaml`) outside of container images. This lets you change settings without rebuilding your images.
>
> 💡 **Beginner tip:** Think of a ConfigMap like a USB stick you plug into a container — it carries config files the app needs to run.

```bash
kubectl apply -f configmap/apache-configmap.yaml
kubectl apply -f configmap/rabbitmq-configmap.yaml
```

---

## Step 6 — Create Apps Namespace and Deploy App ConfigMaps

> **What this does:** A **Namespace** is like a folder in Kubernetes — it isolates one group's resources from another. We put our apps in an `apps` namespace to keep them separate from infrastructure.
>
> 💡 **Beginner tip:** Namespaces prevent accidents. If you delete everything in the `apps` namespace, your infrastructure in `default` stays safe.

```bash
kubectl create namespace apps
kubectl apply -f configmap/java-logging-config.yaml
kubectl apply -f configmap/python-logging-patch.yaml
```

---

## Step 7 — Deploy Apache and RabbitMQ

> **What this does:** We deploy two shared infrastructure services:
> - **Apache** — a web proxy that accepts incoming requests
> - **RabbitMQ** — a message broker that lets services communicate asynchronously
>
> A **Deployment** defines *what* to run (container image, replicas). A **Service** defines *how* to reach it (network name, ports).
>
> 💡 **Beginner tip:** In Kubernetes, you always deploy an app in two parts: a Deployment (the app itself) and a Service (the network address to reach it).

```bash
kubectl apply -f app/apache-deployment.yaml
kubectl apply -f app/apache-service.yaml
kubectl apply -f app/rabbitmq-deployment.yaml
kubectl apply -f app/rabbitmq-service.yaml
```

Wait:

```bash
kubectl rollout status deployment/apache
kubectl rollout status deployment/rabbitmq
```

Verify agent checks (target the node where Apache/RabbitMQ are running):

```bash
APACHE_NODE=$(kubectl get pod -l app=apache -o jsonpath='{.items[0].spec.nodeName}')
AGENT_POD=$(kubectl get pod -l app.kubernetes.io/component=agent -n datadog \
  --field-selector spec.nodeName=$APACHE_NODE \
  -o jsonpath='{.items[0].metadata.name}')
kubectl exec -it -n datadog $AGENT_POD -- agent check apache

RABBIT_NODE=$(kubectl get pod -l app=rabbitmq -o jsonpath='{.items[0].spec.nodeName}')
AGENT_POD=$(kubectl get pod -l app.kubernetes.io/component=agent -n datadog \
  --field-selector spec.nodeName=$RABBIT_NODE \
  -o jsonpath='{.items[0].metadata.name}')
kubectl exec -it -n datadog $AGENT_POD -- agent check rabbitmq
```

---

## Step 8 — Deploy Applications and Services

> **What this does:** We deploy our 3-tier polyglot application:
> - **java-app** (Spring Boot) — the frontend API
> - **python-app** (Flask) — the middleware
> - **dotnet-app** (.NET) — the backend data service
>
> And the **Services** that expose them on LoadBalancer IPs so you can call them.
>
> 💡 **Beginner tip:** The `services.yaml` file contains **ClusterIP** services for internal traffic *and* **LoadBalancer** services so you can hit them from outside the cluster.

```bash
kubectl apply -f builds/metrics/java-app.yaml
kubectl apply -f builds/metrics/python-app.yaml
kubectl apply -f builds/metrics/dotnet-app.yaml
kubectl apply -f builds/metrics/services.yaml
```

Wait:

```bash
kubectl rollout status deployment/java-app -n apps
kubectl rollout status deployment/python-app -n apps
kubectl rollout status deployment/dotnet-app -n apps
```

Check SSI init containers are injected:

```bash
kubectl get pods -n apps -o wide
kubectl describe pod -l app=java-app -n apps | grep -A5 "Init Containers"
```

> 💡 **Beginner tip:** SSI (Single Step Instrumentation) works by injecting **init containers** into your pods. These init containers download and install the tracing library *before* your app starts — you don't write any code.

Check LoadBalancer IPs:

```bash
kubectl get svc -n apps
```

Generate traffic (each curl sends a request through the app chain):

```bash
curl http://$(kubectl get svc java-app -n apps -o jsonpath='{.status.loadBalancer.ingress[0].ip}'):8080/greeting
curl http://$(kubectl get svc python-app -n apps -o jsonpath='{.status.loadBalancer.ingress[0].ip}'):5000/
curl http://$(kubectl get svc python-app -n apps -o jsonpath='{.status.loadBalancer.ingress[0].ip}'):5000/api/dotnet
curl http://$(kubectl get svc dotnet-app -n apps -o jsonpath='{.status.loadBalancer.ingress[0].ip}'):80/weatherforecast
```

> 💡 **Beginner tip:**
> - `/greeting` calls Java → Python → .NET (full trace chain)
> - `/weatherforecast` calls .NET directly
> - The first curl creates a **distributed trace** — Datadog follows the request across all 3 languages
>
> For automatic traffic, run `./populate.sh` to hit all endpoints continuously.

---

## Step 9 — Deploy Monitors and Dashboard

> **What this does:** Terraform creates **monitors** (automated alerts) and a **dashboard** (visual overview) in your Datadog account. Instead of clicking through the Datadog UI, we define them in code.
>
> 💡 **Beginner tip:** **Infrastructure as Code (IaC)** means you write configuration files that describe what you want, and a tool (Terraform) makes it happen — and can also destroy it cleanly when you're done.

First, pass your Datadog credentials to Terraform via environment variables:

```bash
source .env
export TF_VAR_datadog_api_key="$DATADOG_API_KEY"
export TF_VAR_datadog_app_key="$DATADOG_APP_KEY"
```

Then initialize and apply the Terraform configuration:

```bash
cd terraform
terraform init
terraform plan
terraform apply
```

When Terraform asks `Do you want to perform these actions?`, type **yes**.

Creates (via Terraform):

| Resource | Description |
|---|---|
| Monitor: **Pod Memory Usage Above 98%** | Warning at 95%, critical at 98%. Notifies by email. |
| Monitor: **Pod in CrashLoopBackOff** | Fires immediately on crash loop. Notifies by email. |
| Dashboard: **Application Error Dashboard** | Error rate, top errors, log stream, HTTP 5xx, service map. |

Verify:
- 🔔 **Monitors → Manage Monitors** — search `[k8s-lab]`
- 📊 **Dashboards → Dashboard List** — search `Application Error Dashboard`**

> **Legacy shell script method:** `./deprecated/shell-scripts/deploy-datadog-resources.sh` exists but is deprecated. Use Terraform above instead.

---

## Step 10 — Validate the Full Stack

> **What this does:** We verify everything is running by listing pods, services, and the Datadog Agent. This confirms the deployment succeeded.
>
> 💡 **Beginner tip:** `kubectl get pods` is your best friend for debugging. If a pod shows `CrashLoopBackOff` or `Pending`, that's your first clue something needs attention.

```bash
kubectl get pods -n apps -o wide
kubectl get pods -n datadog -o wide
kubectl get svc -n apps
kubectl get datadogagent datadog -n datadog
```

Optional deep validation script (runs everything above + log checks + agent status):

```bash
{
  echo "===== 1. PODS (apps) =====" && kubectl get pods -n apps -o wide && \
  echo "\n===== 2. PODS (datadog) =====" && kubectl get pods -n datadog -o wide && \
  echo "\n===== 3. SERVICES (apps) =====" && kubectl get svc -n apps && \
  echo "\n===== 4. DATADOG AGENT CR =====" && kubectl get datadogagent datadog -n datadog && \
  echo "\n===== 5. JAVA APP LOGS =====" && kubectl logs -l app=java-app -n apps --tail=5 && \
  echo "\n===== 6. PYTHON APP LOGS =====" && kubectl logs -l app=python-app -n apps --tail=5 && \
  echo "\n===== 7. DOTNET APP LOGS =====" && kubectl logs -l app=dotnet-app -n apps --tail=5 && \
  echo "\n===== 8. AGENT STATUS =====" && \
  kubectl exec -it -n datadog $(kubectl get pod -l app.kubernetes.io/component=agent -n datadog -o name | head -1) \
    -- agent status | grep -E "APM Agent|Logs Agent|LogsSent" -A2
} 2>&1 | tee deploy-validation-$(date +%Y%m%d-%H%M%S).txt
```

---

## Datadog UI

| What to check | Where | Filter |
|---|---|---|
| Cluster infrastructure | Infrastructure → Kubernetes | `cluster:datadog-k8s-lab` |
| APM distributed traces | APM → Traces | `env:k8s-lab` |
| APM services | APM → Services | `env:k8s-lab` |
| Logs (apps only) | Logs → Explorer | `service:(java-app OR python-app OR dotnet-app OR apache OR rabbitmq) env:k8s-lab` |
| Apache metrics | Metrics → Explorer | `apache.*` |
| RabbitMQ metrics | Metrics → Explorer | `rabbitmq.*` |
| JVM metrics | Metrics → Explorer | `jvm.*` |
| Monitors | Monitors → Manage | `[k8s-lab]` |
| Dashboard | Dashboards → List | `Application Error Dashboard` |

---

## Teardown

> **What this does:** Terraform destroys the Datadog monitors and dashboard it created. Then `kind` deletes the entire local Kubernetes cluster. Your laptop is back to its original state.
>
> 💡 **Beginner tip:** Always run `terraform destroy` before `kind delete cluster`. If you delete the cluster first, Terraform loses the information it needs to clean up the Datadog resources.

```bash
cd terraform
terraform destroy
kind delete cluster --name datadog-k8s-lab
```

---

## Known Issues & Fixes

| Issue | Root Cause | Fix Applied |
|---|---|---|
| `unknown field spec.features.databaseMonitoring` | Not a valid v2alpha1 CRD field | Moved to `DD_DATABASE_MONITORING_ENABLED` env var |
| Apache 404 on `/server-status` | `mod_status` not enabled in `httpd:latest` | Init container `httpd-setup` patches `httpd.conf` |
| java-app `/greeting` → `UnknownHostException: python-flask` | `GreetingController.java` hardcodes `http://python-flask:8082/api/dotnet` but no Service existed | Created `python-flask` ClusterIP Service with port `8082→5000` |
| python-app `dd.trace_id: "0"` in logs | `ddtrace` pre-installed; SSI aborts injection | Added `import ddtrace.bootstrap.sitecustomize` in ConfigMap |
| ConfigMap namespace mismatch | App ConfigMaps had `namespace: default` but apps run in `apps` | Changed ConfigMaps to `namespace: apps` |
| dotnet-app openmetrics 404 | Demo image has no `/metrics` route | Removed `openmetrics` annotation — APM via SSI |
