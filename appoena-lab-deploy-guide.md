# Appoena Observability Lab — Deploy Guide

Step-by-step guide to deploy the full stack from scratch. All steps validated against a working cluster.

---

## Prerequisites

Install the following tools:

```bash
brew install kind kubectl helm terraform
brew install cloud-provider-kind   # required for LoadBalancer IPs on kind
```

Verify:

```bash
kind version && kubectl version --client && helm version && terraform version
```

You also need:
- A **Datadog account** at [app.datadoghq.com](https://app.datadoghq.com)
- **API Key**: Organization Settings → API Keys
- **App Key**: Organization Settings → Application Keys

---

## Step 0 — Start the LoadBalancer Controller

Keep this running in a dedicated terminal for the entire session:

```bash
sudo cloud-provider-kind
```

This assigns real LoadBalancer IPs to Services of type `LoadBalancer` in kind clusters. Without it, those Services stay in `<pending>` indefinitely.

---

## Step 1 — Create the kind Cluster

```bash
kind create cluster --config kubernetes/kind-config.yaml --name appoena-lab
```

> **Note:** `kubernetes/kind-config.yaml` contains a hardcoded Mac LAN IP (`192.168.15.25`) in `certSANs`. If your local IP has changed, update that field before creating the cluster.

Verify all nodes are Ready:

```bash
kubectl get nodes
```

Expected:

```
NAME                        STATUS   ROLES           AGE
appoena-lab-control-plane   Ready    control-plane   1m
appoena-lab-worker          Ready    <none>          1m
appoena-lab-worker2         Ready    <none>          1m
appoena-lab-worker3         Ready    <none>          1m
```

---

## Step 2 — Install the Datadog Operator

```bash
helm repo add datadog https://helm.datadoghq.com
helm repo update
helm install datadog-operator datadog/datadog-operator --namespace default
```

Wait for the operator to be ready:

```bash
kubectl rollout status deployment/datadog-operator -n default
```

---

## Step 3 — Create the Datadog Secret

Replace with your actual keys:

```bash
kubectl create secret generic datadog-secret \
  --from-literal=api-key=YOUR_API_KEY \
  --from-literal=app-key=YOUR_APP_KEY \
  --namespace default
```

> Do **not** apply `kubernetes/datadog-secret.yaml` directly — it contains placeholder values only.

---

## Step 4 — Deploy the Datadog Agent

```bash
kubectl apply -f kubernetes/datadog-agent.yaml
```

Wait for the DaemonSet and Cluster Agent:

```bash
kubectl rollout status daemonset/datadog-agent -n default
kubectl rollout status deployment/datadog-cluster-agent -n default
```

Expected: one `datadog-agent-*` pod per node (4 total) + one `datadog-cluster-agent-*` pod.

Check Datadog UI: **Infrastructure → Kubernetes** — cluster `appoena-lab` appears in 2–3 minutes.

---

## Step 5 — Deploy ConfigMaps (default namespace)

```bash
kubectl apply -f configmap/apache-configmap.yaml
kubectl apply -f configmap/rabbitmq-configmap.yaml
```

---

## Step 6 — Create apps namespace and deploy app ConfigMaps

Apps must run in the `apps` namespace to receive SSI instrumentation (the `default` namespace is excluded).

```bash
kubectl create namespace apps
kubectl apply -f configmap/java-logging-config.yaml
kubectl apply -f configmap/python-logging-patch.yaml
```

**`java-logging-config.yaml`** — Logback XML ConfigMap that writes structured JSON logs with `dd.trace_id` and `dd.span_id` from MDC.

**`python-logging-patch.yaml`** — Python entrypoint ConfigMap that:
- Imports `ddtrace.bootstrap.sitecustomize` to enable log injection (needed because ddtrace is pre-installed in the image)
- Defines a `DDJsonFormatter` that serializes trace context fields
- Defines both `GET /` and `GET /api/dotnet` Flask routes (the second is called by java-app)

---

## Step 7 — Deploy Apache and RabbitMQ

```bash
kubectl apply -f app/apache-deployment.yaml
kubectl apply -f app/apache-service.yaml
kubectl apply -f app/rabbitmq-deployment.yaml
kubectl apply -f app/rabbitmq-service.yaml
```

Wait for rollouts:

```bash
kubectl rollout status deployment/apache
kubectl rollout status deployment/rabbitmq
```

**RabbitMQ stdout logging:** The deployment sets `RABBITMQ_LOGS: "-"` which routes all RabbitMQ logs to stdout. The Datadog agent collects container stdout automatically. No log file volume or path configuration is needed.

Verify the Datadog checks are running (target the correct node agent):

```bash
APACHE_NODE=$(kubectl get pod -l app=apache -o jsonpath='{.items[0].spec.nodeName}')
AGENT_POD=$(kubectl get pod -l app.kubernetes.io/component=agent \
  --field-selector spec.nodeName=$APACHE_NODE \
  -o jsonpath='{.items[0].metadata.name}')
kubectl exec -it $AGENT_POD -- agent check apache

RABBIT_NODE=$(kubectl get pod -l app=rabbitmq -o jsonpath='{.items[0].spec.nodeName}')
AGENT_POD=$(kubectl get pod -l app.kubernetes.io/component=agent \
  --field-selector spec.nodeName=$RABBIT_NODE \
  -o jsonpath='{.items[0].metadata.name}')
kubectl exec -it $AGENT_POD -- agent check rabbitmq
```

---

## Step 8 — Deploy Applications (Java, Python, .NET) and Services

```bash
kubectl apply -f builds/metrics/java-app.yaml
kubectl apply -f builds/metrics/python-app.yaml
kubectl apply -f builds/metrics/dotnet-app.yaml
kubectl apply -f builds/metrics/services.yaml
```

`services.yaml` creates:
- `java-app` LoadBalancer (port 8080)
- `python-app` LoadBalancer (port 5000)
- `dotnet-app` LoadBalancer (port 80)
- `python-flask` ClusterIP alias (ports 80→5000, 5000→5000, **8082→5000**) — required because `GreetingController.java` hardcodes `http://python-flask:8082/api/dotnet`

Wait for rollouts:

```bash
kubectl rollout status deployment/java-app -n apps
kubectl rollout status deployment/python-app -n apps
kubectl rollout status deployment/dotnet-app -n apps
```

Verify SSI injected init containers (each app pod should show `datadog-lib-*-init` as an init container):

```bash
kubectl get pods -n apps -o wide
kubectl describe pod -l app=java-app -n apps | grep -A5 "Init Containers"
```

Check LoadBalancer IPs assigned by cloud-provider-kind:

```bash
kubectl get svc -n apps
```

Expected (IPs may differ):

```
NAME           TYPE           CLUSTER-IP      EXTERNAL-IP     PORT(S)
dotnet-app     LoadBalancer   10.96.x.x       192.168.97.7    80:xxxxx/TCP
java-app       LoadBalancer   10.96.x.x       192.168.97.8    8080:xxxxx/TCP
python-app     LoadBalancer   10.96.x.x       192.168.97.6    5000:xxxxx/TCP
python-flask   ClusterIP      10.96.x.x       <none>          80/TCP,5000/TCP,8082/TCP
```

Generate traffic to trigger distributed traces:

```bash
curl http://192.168.97.8:8080/greeting
curl http://192.168.97.6:5000/
curl http://192.168.97.6:5000/api/dotnet
curl http://192.168.97.7:80/weatherforecast
```

Use `kubectl get svc -n apps` to confirm the actual IPs on your machine.

The `/greeting` call on java-app triggers the full distributed trace chain:

```
java-app /greeting
  └── calls http://python-flask:8082/api/dotnet   (same trace_id propagated)
        └── python-app /api/dotnet
              └── calls http://dotnet-app/weatherforecast
                    └── dotnet-app /weatherforecast
```

---

## Step 9 — Deploy Monitors and Dashboard

```bash
# Option A — Shell script (recommended, no Terraform)
export DATADOG_API_KEY=YOUR_API_KEY
export DATADOG_APP_KEY=YOUR_APP_KEY
./scripts/deploy-datadog-resources.sh

# Option B — Terraform (legacy)
# cd terraform
# terraform init
# terraform apply \
#   -var="datadog_api_key=YOUR_API_KEY" \
#   -var="datadog_app_key=YOUR_APP_KEY"
```

Creates:

| Resource | Description |
|---|---|
| Monitor: **Pod Memory Usage Above 75%** | Warning at 60%, critical at 75%. Notifies by email. |
| Monitor: **Pod in CrashLoopBackOff** | Fires immediately on crash loop. Notifies by email. |
| Dashboard: **Application Error Dashboard** | Error rate, top errors, log stream, HTTP 5xx, service map. |

Verify in Datadog:
- **Monitors → Manage Monitors** — search `[mentoria]`
- **Dashboards → Dashboard List** — search `Application Error Dashboard`

---

## Step 10 — Validate the Full Stack

```bash
{
  echo "===== 1. ALL PODS (apps namespace) =====" && \
  kubectl get pods -n apps -o wide && \

  echo "\n===== 2. ALL PODS (default namespace) =====" && \
  kubectl get pods -o wide && \

  echo "\n===== 3. ALL SERVICES (apps namespace) =====" && \
  kubectl get svc -n apps && \

  echo "\n===== 4. APACHE CHECK =====" && \
  APACHE_NODE=$(kubectl get pod -l app=apache -o jsonpath='{.items[0].spec.nodeName}') && \
  AGENT_POD=$(kubectl get pod -l app.kubernetes.io/component=agent \
    --field-selector spec.nodeName=$APACHE_NODE \
    -o jsonpath='{.items[0].metadata.name}') && \
  echo "Apache on node: $APACHE_NODE — Agent: $AGENT_POD" && \
  kubectl exec -it $AGENT_POD -- agent check apache | grep -E "Service Checks|Metric Samples|Instance ID" && \

  echo "\n===== 5. RABBITMQ CHECK =====" && \
  RABBIT_NODE=$(kubectl get pod -l app=rabbitmq -o jsonpath='{.items[0].spec.nodeName}') && \
  AGENT_POD=$(kubectl get pod -l app.kubernetes.io/component=agent \
    --field-selector spec.nodeName=$RABBIT_NODE \
    -o jsonpath='{.items[0].metadata.name}') && \
  echo "RabbitMQ on node: $RABBIT_NODE — Agent: $AGENT_POD" && \
  kubectl exec -it $AGENT_POD -- agent check rabbitmq | grep -E "Service Checks|Metric Samples|Instance ID|Error" && \

  echo "\n===== 6. JAVA APP LOGS =====" && \
  kubectl logs -l app=java-app -n apps --tail=5 && \

  echo "\n===== 7. PYTHON APP LOGS =====" && \
  kubectl logs -l app=python-app -n apps --tail=5 && \

  echo "\n===== 8. DOTNET APP LOGS =====" && \
  kubectl logs -l app=dotnet-app -n apps --tail=5 && \

  echo "\n===== 9. AGENT APM + LOGS STATUS =====" && \
  kubectl exec -it $(kubectl get pod -l app.kubernetes.io/component=agent -o name | head -1) \
    -- agent status | grep -E "APM Agent|Logs Agent|feature_apm_enabled|feature_auto_instrumentation|LogsSent" -A2 && \

  echo "\n===== 10. DATADOG AGENT CR STATUS =====" && \
  kubectl get datadogagent datadog -o jsonpath='{.status}' | python3 -m json.tool

} 2>&1 | tee deploy-validation-$(date +%Y%m%d-%H%M%S).txt
```

---

## Datadog UI Verification

| What to check | Where | Filter |
|---|---|---|
| Cluster infrastructure | Infrastructure → Kubernetes | `cluster:appoena-lab` |
| APM distributed traces | APM → Traces | `env:mentoria` |
| APM services | APM → Services | `env:mentoria` |
| Logs (apps only) | Logs → Explorer | `service:(java-app OR python-app OR dotnet-app OR apache OR rabbitmq) env:mentoria` |
| Apache metrics | Metrics → Explorer | `apache.*` |
| RabbitMQ metrics | Metrics → Explorer | `rabbitmq.*` |
| JVM metrics | Metrics → Explorer | `jvm.*` |
| Monitors | Monitors → Manage | `[mentoria]` |
| Dashboard | Dashboards → List | `Application Error Dashboard` |

---

## Teardown

```bash
# Destroy Datadog monitors and dashboard (shell script — recommended)
./scripts/destroy-datadog-resources.sh

# Delete the kind cluster — removes all Kubernetes resources
kind delete cluster --name appoena-lab

# Alternatively — Terraform teardown (legacy)
# cd terraform && terraform destroy \
#   -var="datadog_api_key=YOUR_API_KEY" \
#   -var="datadog_app_key=YOUR_APP_KEY"
```

---

## Repository Structure

```
kubernetes/
  kind-config.yaml          # Cluster: 1 control-plane + 3 workers, linux/arm64
  datadog-agent.yaml        # DatadogAgent CR (v2alpha1) — agent 7.79.0, SSI, extraConfd log rules
  datadog-secret.yaml       # Template only — create secret via kubectl, never apply this file

app/
  apache-deployment.yaml    # Apache with mod_status init container (default namespace)
  apache-service.yaml       # ClusterIP port 80
  rabbitmq-deployment.yaml  # RabbitMQ management, RABBITMQ_LOGS="-" for stdout (default namespace)
  rabbitmq-service.yaml     # ClusterIP ports 5672 + 15672

configmap/
  apache-configmap.yaml     # Reference — checks/logs driven by pod annotations
  rabbitmq-configmap.yaml   # Reference — checks/logs driven by pod annotations
  java-logging-config.yaml  # Logback JSON pattern with dd.trace_id (apps namespace)
  python-logging-patch.yaml # Flask entrypoint: ddtrace bootstrap + DDJsonFormatter + /api/dotnet route (apps namespace)

builds/metrics/
  java-app.yaml             # Spring Boot — SSI annotation, port 8080, LoadBalancer
  python-app.yaml           # Flask py311 — SSI annotation, port 5000, LoadBalancer
  dotnet-app.yaml           # ASP.NET Core — SSI annotation, port 80, LoadBalancer
  services.yaml             # All app Services including python-flask alias (ports 80/5000/8082→5000)

scripts/
  deploy-datadog-resources.sh   # Creates Datadog monitors + dashboard via API (no Terraform)
  destroy-datadog-resources.sh  # Deletes Datadog monitors + dashboard via API

terraform/
  providers.tf              # Datadog provider ~3.0
  variables.tf              # api_key, app_key, notification_email, env
  monitors.tf               # Pod memory alert + CrashLoopBackOff monitor
  dashboard.tf              # Application Error Dashboard
```

---

## Known Issues & Fixes Applied

| Issue | Root Cause | Fix Applied |
|---|---|---|
| `unknown field spec.features.databaseMonitoring` | Not a valid v2alpha1 CRD field | Moved to `DD_DATABASE_MONITORING_ENABLED` env var |
| `unknown field spec.features.eventCollection.enabled` | Wrong field name in CRD schema | Changed to `collectKubernetesEvents: true` |
| Apache 404 on `/server-status` | `mod_status` not enabled in `httpd:latest` | Init container `httpd-setup` patches `httpd.conf` |
| `agent check apache/rabbitmq` — no valid check found | Command ran on wrong node agent | Use `--field-selector spec.nodeName=` to target the correct agent |
| RabbitMQ log collection — Bytes Read: 0 | Default log destination was a file path inside a container; Datadog agent cannot access it | Changed `RABBITMQ_LOGS: "-"` to route logs to stdout; removed emptyDir log volume |
| java-app `/greeting` → `UnknownHostException: python-flask` | `GreetingController.java:28` hardcodes `http://python-flask:8082/api/dotnet` but no Service named `python-flask` existed | Created `python-flask` ClusterIP Service with selector `app: python-app` |
| java-app `/greeting` → 136-second TCP timeout (DNS resolves but connection hangs) | `python-flask` Service had ports 80 and 5000 only; java-app connects on port 8082 (confirmed via `/proc/net/tcp6` SYN_SENT analysis) | Added port `8082→5000` to the `python-flask` Service |
| python-app `dd.trace_id: "0"` and `dd.service: ""` in logs | `ddtrace` is pre-installed in the image; SSI's `sitecustomize.py` detects it and aborts trace injection | Added `import ddtrace.bootstrap.sitecustomize` at the top of `entrypoint.py` ConfigMap — initializes ddtrace log injection without image rebuild |
| python-app `/api/dotnet` → 404 | Flask app had only `GET /`; java-app calls `/api/dotnet` on python-flask | Added `GET /api/dotnet` route to `entrypoint.py` ConfigMap — calls `http://dotnet-app/weatherforecast` and returns the response |
| ConfigMap namespace mismatch | `java-logging-config.yaml` and `python-logging-patch.yaml` had `namespace: default`; apps run in `apps` namespace and cannot mount ConfigMaps from another namespace | Changed both ConfigMaps to `namespace: apps` |
| java-app and python-app openmetrics 404 | Demo images do not expose a Prometheus `/metrics` endpoint | Removed `openmetrics` autodiscovery annotations — observability is via APM + log injection |
| dotnet-app openmetrics 404 | ASP.NET Core demo image has no `/metrics` route | Removed `openmetrics` annotation — APM traces and logs work via SSI |
| kube-controller-manager check broken on kind | Check is not in catalog for kind clusters | Added `DD_IGNORE_AUTOCONF: kube_controller_manager` to node agent env |
| kube-system logs in Logs Explorer | `containerCollectAll: true` collects all namespaces | Added `DD_CONTAINER_EXCLUDE_LOGS` for `kube-system` and `local-path-storage` |
| eBPF kprobe errors in agent diagnostics | kind runs on macOS via OrbStack; tracefs is shared and locked by the VM kernel | Expected/harmless — all Datadog connectivity checks succeed |
| python-app DogStatsD `Connection refused` in logs | Demo image sends UDP metrics to `localhost:8125`; DogStatsD socket lives on the node agent host | Expected behavior for this demo image. APM traces and logs work correctly. Fix if needed: set `DD_AGENT_HOST` to `status.hostIP` via downward API |
