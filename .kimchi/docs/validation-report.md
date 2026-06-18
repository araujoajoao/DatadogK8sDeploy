# Validation Report — Appoena Observability Lab

## TL;DR
The lab is **mostly correct and deployable** if the commands are followed exactly. There are **minor inconsistencies** between README and manifests, and a few commands that could fail due to missing namespace flags or timing issues.

---

## Step-by-step Validity Check

### Prerequisites
| Command | Status | Notes |
|---------|--------|-------|
| `brew install kind kubectl helm terraform` | ✅ | Standard tools |
| `brew install cloud-provider-kind` | ✅ | Required for LoadBalancer IPs in kind |

---

### Step 0 — `sudo cloud-provider-kind`
| Check | Status | Notes |
|-------|--------|-------|
| Command | ✅ | Opens a terminal that must stay open. Without it, all `LoadBalancer` Services stay `<pending>`. |

---

### Step 1 — Create the kind cluster
| Command | Status | Notes |
|---------|--------|-------|
| `kind create cluster --config kubernetes/kind-config.yaml --name appoena-lab` | ✅ | Creates 1 control-plane + 3 workers. |
| `kubectl get nodes` | ✅ | Expect 4 Ready nodes. |

**⚠️ Warning:** `kubernetes/kind-config.yaml` hardcodes `certSANs: ["192.168.15.25"]` — the Mac LAN IP. If your IP has changed, the Kubernetes API server certificate will not include your current IP. For local kind this is usually harmless, but if API-server access fails from outside the VM, this is the cause.

---

### Step 2 — Install the Datadog Operator
| Command | Status | Notes |
|---------|--------|-------|
| `helm repo add datadog ... && helm repo update` | ✅ | Standard |
| `helm install datadog-operator datadog/datadog-operator --namespace default` | ✅ | Installs operator into `default`. No `--create-namespace` needed. |
| `kubectl rollout status deployment/datadog-operator -n default` | ✅ | Correct namespace. |

---

### Step 3 — Create the Datadog Secret
| Command | Status | Notes |
|---------|--------|-------|
| `kubectl create secret generic datadog-secret ... --namespace default` | ✅ | Correct. |

**⚠️ DO NOT APPLY** `kubernetes/datadog-secret.yaml`. The README and deploy guide correctly warn against this. The file contains real-looking base64 values that could be mistaken for a real secret.

---

### Step 4 — Deploy the Datadog Agent
| Command | Status | Notes |
|---------|--------|-------|
| `kubectl apply -f kubernetes/datadog-agent.yaml` | ✅ | Applies the `DatadogAgent` CR (v2alpha1). |
| `kubectl rollout status daemonset/datadog-agent` | ⚠️ | **Missing `-n default`**. If your current kubectl context is in another namespace (e.g. `apps`), this command fails with "daemonset not found". |
| `kubectl rollout status deployment/datadog-cluster-agent` | ⚠️ | Same: **missing `-n default`**. |

**Fix:**
```bash
kubectl rollout status daemonset/datadog-agent -n default
kubectl rollout status deployment/datadog-cluster-agent -n default
```

**Inconsistency:** README says Datadog Agent version `7.79.0`, but `datadog-agent.yaml` overrides both `nodeAgent.image.tag` and `clusterAgent.image.tag` to `7.80.0`. The deployed version will be **7.80.0**, not 7.79.0. This is benign but should be aligned.

---

### Step 5 — Deploy ConfigMaps (default namespace)
| Command | Status | Notes |
|---------|--------|-------|
| `kubectl apply -f configmap/apache-configmap.yaml` | ✅ | Correct namespace (`default`) inside the file. |
| `kubectl apply -f configmap/rabbitmq-configmap.yaml` | ✅ | Correct namespace (`default`). |

---

### Step 6 — Create apps namespace and deploy app ConfigMaps
| Command | Status | Notes |
|---------|--------|-------|
| `kubectl create namespace apps` | ✅ | Required. SSI is disabled in `default`. |
| `kubectl apply -f configmap/java-logging-config.yaml` | ✅ | Namespace is `apps` in the file. Correct. |
| `kubectl apply -f configmap/python-logging-patch.yaml` | ✅ | Namespace is `apps`. Correct. |

**Note:** The manifest for `python-logging-patch.yaml` imports `ddtrace.bootstrap.sitecustomize` at the top. This works around the pre-installed `ddtrace` in the image. The deploy guide correctly explains this.

---

### Step 7 — Deploy Apache and RabbitMQ
| Command | Status | Notes |
|---------|--------|-------|
| `kubectl apply -f app/` | ✅ | Applies all 4 YAML files in the `app/` directory. This works. |
| Individual `kubectl apply -f app/...` | ✅ | Also valid, as shown in the deploy guide's verbose Step 7. |
| `kubectl rollout status deployment/apache` | ✅ | Defaults to `default` namespace, where the deployment lives. |
| `kubectl rollout status deployment/rabbitmq` | ✅ | Same. |

**RabbitMQ stdout logging:** The deployment sets `RABBITMQ_LOGS: "-"`, which correctly routes logs to stdout. The Datadog agent picks these up via `containerCollectAll: true`.

**Apache `agent check` commands:** The guide constructs `AGENT_POD` dynamically using `--field-selector spec.nodeName=$APACHE_NODE`. This is correct and fixes a common pitfall of running the check on the wrong node's agent. ✅

---

### Step 8 — Deploy Applications and Services
| Command | Status | Notes |
|---------|--------|-------|
| `kubectl apply -f builds/metrics/` | ✅ | Applies java-app, python-app, dotnet-app, and services. This works. |
| `kubectl rollout status deployment/java-app -n apps` | ✅ | Correct namespace. |
| `kubectl rollout status deployment/python-app -n apps` | ✅ | Correct namespace. |
| `kubectl rollout status deployment/dotnet-app -n apps` | ✅ | Correct namespace. |

**SSI injection check:**
```bash
kubectl describe pod -l app=java-app -n apps | grep -A5 "Init Containers"
```
This is correct. You should see `datadog-lib-java-init`. ✅

**python-flask Service:** The `services.yaml` correctly creates a `ClusterIP` alias with ports `80→5000`, `5000→5000`, and `8082→5000`. Port 8082 is required because `GreetingController.java` hardcodes `http://python-flask:8082/api/dotnet`. ✅

**LoadBalancer traffic commands:** Use `kubectl get svc -n apps` to discover your actual IPs. The hardcoded IPs in the README (`192.168.97.X`) are examples only. ✅

---

### Step 9 — Deploy Monitors and Dashboard
| Command | Status | Notes |
|---------|--------|-------|
| `export DATADOG_API_KEY=... && export DATADOG_APP_KEY=...` | ✅ | Required environment variables. |
| `./scripts/deploy-datadog-resources.sh` | ✅ | Script correctly validates inputs, uses `set -euo pipefail`, writes state file to `scripts/.datadog-resource-ids.json`. |
| `terraform apply ...` | ✅ | Alternative path. Terraform files (`providers.tf`, `variables.tf`, `monitors.tf`, `dashboard.tf`) exist and are correctly structured. |

---

### Step 10 — Validate the Full Stack
| Command | Status | Notes |
|---------|--------|-------|
| `kubectl get pods -n apps -o wide` | ✅ | Checks apps. |
| `kubectl get pods -o wide` | ✅ | Checks default namespace (agent, apache, rabbitmq). |
| `kubectl get svc -n apps` | ✅ | Checks services. |
| Apache / RabbitMQ `agent check` commands | ✅ | Dynamically resolves correct node agent via `field-selector`. |
| `kubectl logs -l app=java-app -n apps --tail=5` | ✅ | Checks Java logs. |
| `kubectl logs -l app=dotnet-app -n apps --tail=5` | ✅ | Checks .NET logs. |
| `agent status` via exec | ✅ | Checks APM, logs, and feature flags. |
| `kubectl get datadogagent datadog -o jsonpath='{.status}' | python3 -m json.tool` | ✅ | Verifies the DatadogAgent CR status. |

---

## Issues Flagged

### 🔴 Must Fix (causes failure)
1. **`kubectl rollout status` missing namespace flag** in Step 4. If the user switched contexts or namespaces, `daemonset/datadog-agent` is not found.

### 🟡 Should Fix (confusion / inconsistency)
2. **Datadog Agent version mismatch:** README says `7.79.0`; `datadog-agent.yaml` deploys `7.80.0`. Pick one and align.
3. **`certSANs` IP in kind-config.yaml** is hardcoded to `192.168.15.25`. Users on different networks should update this or be aware it may be stale.
4. **`populate.sh` is not referenced** in the README or deploy guide, but it is a useful traffic generator. Consider adding a mention.

### 🟢 Info / Acknowledged
5. **eBPF kprobe errors** on macOS kind clusters are expected and harmless (documented in Known Issues).
6. **Python DogStatsD `Connection refused`** is expected because the demo image sends UDP to `localhost:8125` instead of the node agent's host IP. APM and logs still work.

---

## Verification Checklist for a Fresh Deploy

Copy-paste this after running all steps:

```bash
# 0. cloud-provider-kind is running
sudo cloud-provider-kind &

# 1. Cluster exists and has 4 nodes
kind get clusters | grep appoena-lab
kubectl get nodes

# 2. Operator is ready
kubectl rollout status deployment/datadog-operator -n default

# 3. Secret exists
kubectl get secret datadog-secret -n default

# 4. Datadog Agent DaemonSet + Cluster Agent are ready
kubectl rollout status daemonset/datadog-agent -n default
kubectl rollout status deployment/datadog-cluster-agent -n default

# 5. ConfigMaps in both namespaces
kubectl get cm -n default
kubectl get cm -n apps

# 6. Apache and RabbitMQ are ready
kubectl rollout status deployment/apache -n default
kubectl rollout status deployment/rabbitmq -n default

# 7. Apps are ready
kubectl rollout status deployment/java-app -n apps
kubectl rollout status deployment/python-app -n apps
kubectl rollout status deployment/dotnet-app -n apps

# 8. Services have external IPs
kubectl get svc -n apps

# 9. SSI init containers were injected
kubectl get pods -n apps -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{range .spec.initContainers[*]}{"  init: "}{.name}{"\n"}{end}{end}'

# 10. Generate traffic and verify traces/logs appear in Datadog
# (wait 2–3 minutes after the first curl)
curl "http://$(kubectl get svc java-app -n apps -o jsonpath='{.status.loadBalancer.ingress[0].ip}'):8080/greeting"
```
