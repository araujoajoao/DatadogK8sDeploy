# Appoena Observability Lab — Deploy Guide

Step-by-step guide to deploy the full stack from scratch. All steps validated and include fixes for all known issues.

---

## Prerequisites

Install the following tools:

```bash
brew install kind
brew install kubectl
brew install helm
brew install terraform
```

Verify installations:

```bash
kind version
kubectl version --client
helm version
terraform version
```

You also need:
- A **Datadog trial account** at [app.datadoghq.com](https://app.datadoghq.com)
- Your **API Key**: Datadog → Organization Settings → API Keys
- Your **App Key**: Datadog → Organization Settings → Application Keys

---

## Step 1 — Create the kind Cluster

```bash
kind create cluster --config kubernetes/kind-config.yaml --name appoena-lab
```

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

helm install datadog-operator datadog/datadog-operator \
  --namespace default
```

Wait for the operator to be ready:

```bash
kubectl rollout status deployment/datadog-operator -n default
```

> **Important:** Install the operator in `default` namespace — this keeps all resources together and avoids Helm release conflicts.

---

## Step 3 — Create the Datadog Secret

Replace `YOUR_API_KEY` and `YOUR_APP_KEY` with your actual keys:

```bash
kubectl create secret generic datadog-secret \
  --from-literal=api-key=YOUR_API_KEY \
  --from-literal=app-key=YOUR_APP_KEY \
  --namespace default
```

Verify:

```bash
kubectl get secret datadog-secret
```

> Do **not** apply `kubernetes/datadog-secret.yaml` directly — it contains placeholder values.

---

## Step 4 — Deploy the Datadog Agent

```bash
kubectl apply -f kubernetes/datadog-agent.yaml
```

Wait for the DaemonSet and Cluster Agent to be ready:

```bash
kubectl rollout status daemonset/datadog-agent
kubectl rollout status deployment/datadog-cluster-agent
```

Verify all agent pods are running:

```bash
kubectl get pods -l app.kubernetes.io/name=datadog
```

Expected: one `datadog-agent-*` pod per node (4 total) + one `datadog-cluster-agent-*` pod.

Check the cluster appears in Datadog:
- Go to **Infrastructure → Kubernetes**
- Cluster `appoena-lab` should appear within 2–3 minutes

> **Important notes about `datadog-agent.yaml`:**
> - Agent version `7.78.1` for both nodeAgent and clusterAgent
> - `eventCollection.collectKubernetesEvents: true` — not `enabled: true` (invalid field)
> - `databaseMonitoring` is NOT in the features block — enabled via `DD_DATABASE_MONITORING_ENABLED` env var
> - `DD_CONTAINER_EXCLUDE_LOGS` excludes `kube-system` and `local-path-storage` namespaces from log collection
> - `DD_IGNORE_AUTOCONF: kube_controller_manager` suppresses a broken check on kind clusters

---

## Step 5 — Deploy ConfigMaps

```bash
kubectl apply -f configmap/apache-configmap.yaml
kubectl apply -f configmap/rabbitmq-configmap.yaml
```

---

## Step 6 — Deploy Apache

```bash
kubectl apply -f app/apache-deployment.yaml
kubectl apply -f app/apache-service.yaml
```

Wait for rollout:

```bash
kubectl rollout status deployment/apache
```

Verify `mod_status` is responding:

```bash
APACHE_POD=$(kubectl get pod -l app=apache -o jsonpath='{.items[0].metadata.name}')
kubectl exec -it $APACHE_POD -- \
  sh -c "printf 'GET /server-status?auto HTTP/1.0\r\nHost: localhost\r\n\r\n' | nc localhost 80"
```

Verify the Datadog check on the correct node agent:

```bash
APACHE_NODE=$(kubectl get pod -l app=apache -o jsonpath='{.items[0].spec.nodeName}')
AGENT_POD=$(kubectl get pod -l app.kubernetes.io/component=agent \
  --field-selector spec.nodeName=$APACHE_NODE \
  -o jsonpath='{.items[0].metadata.name}')
kubectl exec -it $AGENT_POD -- agent check apache
```

Expected: metrics like `apache.net.hits`, `apache.net.bytes`, `apache.performance.busy_workers`.

> **Note:** `apache-deployment.yaml` uses an init container named `httpd-setup` to enable `mod_status`. The annotation `ad.datadoghq.com/httpd-setup.exclude: "true"` prevents Datadog from autodiscovering the init container.

---

## Step 7 — Deploy RabbitMQ

```bash
kubectl apply -f app/rabbitmq-deployment.yaml
kubectl apply -f app/rabbitmq-service.yaml
```

Wait for rollout:

```bash
kubectl rollout status deployment/rabbitmq
```

Verify the management API:

```bash
RABBIT_POD=$(kubectl get pod -l app=rabbitmq -o jsonpath='{.items[0].metadata.name}')
kubectl exec -it $RABBIT_POD -- \
  curl -s http://localhost:15672/api/overview -u guest:guest | head -c 200
```

Verify the Datadog check on the correct node agent:

```bash
RABBIT_NODE=$(kubectl get pod -l app=rabbitmq -o jsonpath='{.items[0].spec.nodeName}')
AGENT_POD=$(kubectl get pod -l app.kubernetes.io/component=agent \
  --field-selector spec.nodeName=$RABBIT_NODE \
  -o jsonpath='{.items[0].metadata.name}')
kubectl exec -it $AGENT_POD -- agent check rabbitmq
```

Expected: `rabbitmq.aliveness` and `rabbitmq.status` with status 0 (OK), 15 metric samples.

> **Note:** `RABBITMQ_LOGS` env var is set to write logs to a file instead of stdout so Datadog log collection works.

---

## Step 8 — Deploy Applications (Java, Python, .NET)

```bash
kubectl apply -f builds/metrics/java-app.yaml
kubectl apply -f builds/metrics/python-app.yaml
kubectl apply -f builds/metrics/dotnet-app.yaml
```

Wait for all rollouts:

```bash
kubectl rollout status deployment/java-app
kubectl rollout status deployment/python-app
kubectl rollout status deployment/dotnet-app
```

Verify pods are running:

```bash
kubectl get pods -l app=java-app
kubectl get pods -l app=python-app
kubectl get pods -l app=dotnet-app
```

Generate traffic to trigger APM traces:

```bash
JAVA_POD=$(kubectl get pod -l app=java-app -o jsonpath='{.items[0].metadata.name}')
kubectl port-forward $JAVA_POD 8080:8080 &
sleep 2 && curl http://localhost:8080
kill %1

PYTHON_POD=$(kubectl get pod -l app=python-app -o jsonpath='{.items[0].metadata.name}')
kubectl port-forward $PYTHON_POD 8081:5000 &
sleep 2 && curl http://localhost:8081
kill %1

DOTNET_POD=$(kubectl get pod -l app=dotnet-app -o jsonpath='{.items[0].metadata.name}')
kubectl port-forward $DOTNET_POD 8082:80 &
sleep 2 && curl http://localhost:8082/weatherforecast
kill %1
```

Confirm APM traces are being sent:

```bash
PYTHON_POD=$(kubectl get pod -l app=python-app -o jsonpath='{.items[0].metadata.name}')
kubectl logs $PYTHON_POD --tail=10 | grep -i "sent\|trace"
```

> **Note:** These demo images do not expose Prometheus `/metrics` endpoints. Observability is via APM traces and log injection only. The `openmetrics` check annotation has been removed from all three apps.

> **Note (Python DogStatsD):** The python-app may log `Error submitting packet: [Errno 111] Connection refused` for DogStatsD. This happens because the app sends UDP metrics to `localhost:8125`, but inside Kubernetes the DogStatsD socket lives on the node agent. APM traces and logs still work correctly — this warning only affects custom DogStatsD metrics from this demo image.

---

## Step 9 — Deploy Monitors and Dashboard (Terraform)

```bash
cd terraform
terraform init
```

Apply with your Datadog keys:

```bash
terraform apply \
  -var="datadog_api_key=YOUR_API_KEY" \
  -var="datadog_app_key=YOUR_APP_KEY"
```

This creates:

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

Run all checks and save output to file:

```bash
{
  echo "===== 1. ALL PODS =====" && \
  kubectl get pods -o wide && \

  echo "\n===== 2. ALL SERVICES =====" && \
  kubectl get services && \

  echo "\n===== 3. ALL DEPLOYMENTS =====" && \
  kubectl get deployments && \

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

  echo "\n===== 6. JAVA APP =====" && \
  kubectl get pods -l app=java-app && \
  kubectl logs -l app=java-app --tail=5 && \

  echo "\n===== 7. PYTHON APP =====" && \
  kubectl get pods -l app=python-app && \
  kubectl logs -l app=python-app --tail=5 && \

  echo "\n===== 8. DOTNET APP =====" && \
  kubectl get pods -l app=dotnet-app && \
  kubectl logs -l app=dotnet-app --tail=5 && \

  echo "\n===== 9. AGENT STATUS SUMMARY =====" && \
  kubectl exec -it $(kubectl get pod -l app.kubernetes.io/component=agent -o name | head -1) \
    -- agent status | grep -E "feature_apm_enabled|feature_auto_instrumentation|Running Checks|APM Agent|Logs Agent|LogsSent|Status: Running|Uptime" -A1 && \

  echo "\n===== 10. APM STATUS =====" && \
  kubectl exec -it $(kubectl get pod -l app.kubernetes.io/component=agent -o name | head -1) \
    -- agent status | grep -A5 "APM Agent" && \

  echo "\n===== 11. LOGS AGENT STATUS =====" && \
  kubectl exec -it $(kubectl get pod -l app.kubernetes.io/component=agent -o name | head -1) \
    -- agent status | grep -A15 "^Logs Agent" && \

  echo "\n===== 12. CONNECTIVITY =====" && \
  kubectl exec -it $(kubectl get pod -l app.kubernetes.io/component=agent -o name | head -1) \
    -- agent diagnose --include connectivity-datadog-core-endpoints 2>&1 | tail -20 && \

  echo "\n===== 13. DATADOG AGENT CR STATUS =====" && \
  kubectl get datadogagent datadog -o jsonpath='{.status}' | python3 -m json.tool && \

  echo "\n===== 14. CLUSTER AGENT STATUS =====" && \
  kubectl exec -it $(kubectl get pod -l app.kubernetes.io/component=cluster-agent -o name) \
    -- datadog-cluster-agent status | grep -E "Running Checks|Service Checks|Metric Sample|Event:|Flushed|WARNING|ERROR" -A2

} 2>&1 | tee deploy-validation-$(date +%Y%m%d-%H%M%S).txt
```

---

## Datadog UI Verification

| What to check | Where | Filter |
|---|---|---|
| Cluster infrastructure | Infrastructure → Kubernetes | cluster: appoena-lab |
| APM traces | APM → Services | env: mentoria |
| Logs (apps only) | Logs → Explorer | `service:(apache OR rabbitmq OR java-app OR python-app OR dotnet-app) env:mentoria` |
| APM metrics | Metrics → Explorer | `trace.http.request.hits{env:mentoria}` |
| Runtime metrics | Metrics → Explorer | `jvm.*` / `runtime.*` |
| Apache metrics | Metrics → Explorer | `apache.*` |
| RabbitMQ metrics | Metrics → Explorer | `rabbitmq.*` |
| Kubernetes metrics | Metrics → Explorer | `kubernetes.cpu.usage.total` |

> **Tip:** Save the log filter `service:(apache OR rabbitmq OR java-app OR python-app OR dotnet-app) env:mentoria` as a view in Logs Explorer for quick access to application logs only.

---

## Teardown

```bash
# Destroy Terraform resources first
cd terraform && terraform destroy \
  -var="datadog_api_key=YOUR_API_KEY" \
  -var="datadog_app_key=YOUR_APP_KEY"

# Delete the kind cluster — removes all Kubernetes resources
kind delete cluster --name appoena-lab
```

---

## File Reference

```
kubernetes/
  kind-config.yaml          # Cluster: 1 control-plane + 3 workers
  datadog-agent.yaml        # Datadog Operator CR — agent v7.78.1 + all features
  datadog-secret.yaml       # Secret template (replace keys before use)

app/
  apache-deployment.yaml    # Apache with mod_status init container + Datadog autodiscovery
  apache-service.yaml       # ClusterIP on port 80
  rabbitmq-deployment.yaml  # RabbitMQ management image + log file env var
  rabbitmq-service.yaml     # ClusterIP on ports 5672 and 15672

configmap/
  apache-configmap.yaml     # Apache log paths for Datadog
  rabbitmq-configmap.yaml   # RabbitMQ log paths for Datadog

builds/metrics/
  java-app.yaml             # Java Spring Boot — APM + logs on port 8080
  python-app.yaml           # Python Flask — APM + logs on port 5000
  dotnet-app.yaml           # ASP.NET Core — APM + logs on port 80

terraform/
  providers.tf              # Datadog Terraform provider
  variables.tf              # API/App key inputs
  monitors.tf               # Memory alert + CrashLoopBackOff monitor
  dashboard.tf              # Application Error Dashboard
```

---

## Known Issues & Notes

| Issue | Root Cause | Fix Applied |
|---|---|---|
| `unknown field spec.features.databaseMonitoring` | Not a valid v2alpha1 CRD field | Moved to `DD_DATABASE_MONITORING_ENABLED` env var |
| `unknown field spec.features.eventCollection.enabled` | Wrong field name in CRD schema | Changed to `collectKubernetesEvents: true` |
| Apache 404 on `/server-status` | `mod_status` not enabled in `httpd:latest` | Init container `httpd-setup` patches `httpd.conf` |
| Apache check excluded by autodiscovery | Init container matched `httpd` autodiscovery ID | Renamed to `httpd-setup` + `exclude: "true"` annotation |
| `agent check apache/rabbitmq` — no valid check found | Command ran on wrong node agent | Use `--field-selector spec.nodeName=` to target correct agent |
| `agent check rabbitmq` — no valid check found (right node) | Agent pod restarted recently; check not yet scheduled | Wait ~60s after agent restart and retry; confirmed working at steady state |
| RabbitMQ logs empty | Default logging goes to stdout only | Added `RABBITMQ_LOGS` env var to write to file |
| java-app openmetrics 404 | App does not expose Prometheus endpoint | Removed openmetrics annotation — APM + logs only |
| python-app wrong port | Image exposes port `5000` not `8000` | Fixed `containerPort` to `5000` |
| python-app openmetrics 404 | Flask app has no `/metrics` route | Removed openmetrics annotation — APM + logs only |
| python-app `DogStatsD Connection refused` warnings in logs | App sends UDP metrics to `localhost:8125`; DogStatsD is on the node agent, not localhost | Expected behavior for this demo image — APM traces and logs still work. Fix: set `DD_AGENT_HOST` to `status.hostIP` in the deployment env vars |
| dotnet-app wrong port | Image exposes port `80` via `ASPNETCORE_URLS` | Fixed `containerPort` to `80` |
| dotnet-app openmetrics 404 | ASP.NET Core app has no `/metrics` route | Removed openmetrics annotation — APM + logs only |
| dotnet-app traffic endpoint | Root path `/` returns empty; valid route is `/weatherforecast` | Updated port-forward curl to use `/weatherforecast` |
| kube-controller-manager check broken | Check not in catalog on kind clusters | Added `DD_IGNORE_AUTOCONF: kube_controller_manager` |
| kube-system logs in Logs Explorer | `containerCollectAll: true` collects all namespaces | Added `DD_CONTAINER_EXCLUDE_LOGS` for kube-system and local-path-storage |
| eBPF kprobe errors in connectivity output | kind runs on macOS with a Linux VM; kernel tracefs is shared and locked | Expected/harmless — all other connectivity checks succeed |
| Cluster Agent WARN: unknown env vars `DD_KUBE_STATE_METRICS_CORE_*` | Variables moved to different config path in newer operator versions | Cosmetic warning only; KSM core checks still function correctly |
