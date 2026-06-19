# ☸️🐶 Datadog Kubernetes Observability Lab

[![Validate](https://github.com/araujoajoao/DatadogK8sDeploy/actions/workflows/validate.yml/badge.svg)](https://github.com/araujoajoao/DatadogK8sDeploy/actions/workflows/validate.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Terraform](https://img.shields.io/badge/terraform-%235835CC.svg?style=flat&logo=terraform&logoColor=white)](https://www.terraform.io/)
[![Kubernetes](https://img.shields.io/badge/kubernetes-%23326ce5.svg?style=flat&logo=kubernetes&logoColor=white)](https://kubernetes.io/)

> A hands-on lab for **complete beginners** to learn **observability** — how to watch, trace, and debug distributed systems — using **Datadog** on a **free local Kubernetes cluster**.

---

## 🆕 New to Observability? Start Here!

**Observability** means understanding what your software is doing by looking at its **traces**, **logs**, and **metrics** — instead of guessing.

Think of it like a hospital monitoring a patient:
- 📊 **Metrics** = heart rate, blood pressure (numbers over time)
- 📝 **Logs** = nurse notes (text records of events)
- 🔗 **Traces** = following a single blood cell's journey through the body (tracking one request across many services)

This lab teaches you how to set up all three on a local cluster, **with zero prior experience**.

### What You Will Learn

By the end of this lab, you will understand:

1. ✅ How Kubernetes runs apps in containers and how namespaces organize them
2. ✅ What **APM (Application Performance Monitoring)** is and why it matters
3. ✅ What **distributed tracing** is — following one request across multiple apps
4. ✅ What **logs** are and how to correlate them with traces
5. ✅ What **metrics** are and how to collect them from infrastructure (Apache, RabbitMQ)
6. ✅ How **Datadog SSI (Single Step Instrumentation)** auto-injects tracing with zero code changes
7. ✅ How to define alerts and dashboards as code with **Terraform**

---

## 🎯 Why This Lab?

Most observability tutorials assume you already know Kubernetes, Datadog, and distributed systems. **This one doesn't.**

You will:
- 🏗️ **Build** a complete 3-tier app on a **free local cluster** ([kind](https://kind.sigs.k8s.io/))
- 🔗 **Trace** a request across **Java, Python, and .NET** — and see the **same trace ID** in every language
- 📝 **Correlate logs with traces** — every log line shows the `trace_id` automatically
- 📊 **See infrastructure metrics** — Apache web server and RabbitMQ message broker
- 🔔 **Create alerts as code** — Terraform provisions Datadog monitors and dashboards
- ⚡ **Use zero-manual-instrumentation** — Datadog SSI injects tracing libraries at deploy time

**Cost:** $0 — runs entirely on your laptop.
**Time:** ~30 minutes.
**Prerequisites:** None. We explain every tool as we use it.

---

## 📚 Key Concepts for Beginners

| Term | Plain English | What We'll Do |
|---|---|---|
| **APM** | Watching how your apps perform — response times, errors, slow endpoints | See APM traces in Datadog for every request |
| **Distributed Tracing** | Following one user request as it hops through multiple services | A request hits Java → Python → .NET, all with the **same trace ID** |
| **Single Step Instrumentation (SSI)** | Datadog automatically injects tracing code into your apps — you write **zero** tracing code | One YAML setting enables it for all apps |
| **Log-Trace Correlation** | Every log line carries the same `trace_id` as the APM trace, so you can jump from logs to traces instantly | See `dd.trace_id` in every container log |
| **Metrics** | Numbers measured over time — CPU, memory, request count | View RabbitMQ queue depth and Apache request rate |
| **Infrastructure Monitoring** | Watching the "plumbing" — proxies, message brokers, databases | Monitor Apache and RabbitMQ alongside app traces |
| **Alerting as Code** | Defining when to notify you (e.g., "memory > 98%") in Terraform files instead of clicking in a UI | Deploy monitors and dashboards with `terraform apply` |

> 📖 **Want deeper definitions?** See [GLOSSARY.md](./GLOSSARY.md).

---

## 🏗️ Architecture (What You'll Build)

```
┌─────────────────────────────────────────────┐
│  Your Laptop (kind cluster)                 │
│                                             │
│  ┌─────────────┐    ┌─────────────┐         │
│  │  Apache     │    │  RabbitMQ   │         │
│  │  (proxy)    │    │  (messages) │         │
│  └─────────────┘    └─────────────┘         │
│        ▲                                       │
│        │                                       │
│  ┌─────────────┐    ┌─────────────┐         │
│  │  java-app   │───>│ python-app  │───> .NET│
│  │  (Spring)   │    │  (Flask)    │    app  │
│  └─────────────┘    └─────────────┘         │
│                                             │
│  All traffic → Same trace ID across all 3   │
└─────────────────────────────────────────────┘
```

Every request to `java-app /greeting` calls `python-app` which calls `dotnet-app`, and Datadog traces the entire journey.

---

## 🚀 Quick Start (5 Steps)

```bash
# Step 1: Install tools (see Prerequisites below)
# Step 2: Clone this repo
git clone https://github.com/araujoajoao/DatadogK8sDeploy.git
cd DatadogK8sDeploy

# Step 3: Set up your Datadog credentials
cp .env.example .env
# Edit .env and replace YOUR_API_KEY + YOUR_APP_KEY with real values from Datadog
source .env

# Step 4: Start the local Kubernetes cluster
sudo cloud-provider-kind &        # keep this running in a terminal
kind create cluster --config kubernetes/kind-config.yaml --name datadog-k8s-lab

# Step 5: Deploy everything (the full guide explains each part)
kubectl create secret generic datadog-secret \
  --from-literal=api-key="$DATADOG_API_KEY" \
  --from-literal=app-key="$DATADOG_APP_KEY" \
  -n datadog
kubectl apply -f kubernetes/datadog-agent.yaml
kubectl apply -f configmap/ -f app/ -f builds/metrics/
cd terraform && terraform init && terraform apply
cd .. && ./populate.sh
```

🎯 **That was the 30-second version. For the step-by-step guide with explanations, see [deploy-guide.md](./deploy-guide.md).**

---

## ✅ Prerequisites

You need these tools installed. If you're not sure, run `brew install` on macOS:

| Tool | What It Does | Install Command |
|---|---|---|
| **kind** | Runs a local Kubernetes cluster inside Docker | `brew install kind` |
| **kubectl** | Command-line tool to talk to Kubernetes | `brew install kubectl` |
| **helm** | Package manager for Kubernetes apps | `brew install helm` |
| **terraform** | Infrastructure-as-code for Datadog resources | `brew install terraform` |
| **cloud-provider-kind** | Gives kind clusters LoadBalancer support | `brew install cloud-provider-kind` |

Also:
- [A free Datadog account](https://app.datadoghq.com)
- [A Datadog API Key and App Key](https://docs.datadoghq.com/account_management/api-app-keys/)

---

## 📂 Project Structure

| Folder | What's Inside | For Beginners |
|---|---|---|
| `kubernetes/` | Cluster config + Datadog Agent YAML | The "operating system" of your cluster and the Datadog watchman |
| `app/` | Apache + RabbitMQ deployments | The shared infrastructure your apps depend on |
| `builds/metrics/` | Java, Python, .NET apps + Services | The actual applications you'll trace and monitor |
| `configmap/` | Logging patches and config | Tweaks to make logs and traces work together |
| `terraform/` | Monitors + Dashboard as code | Code that creates alerts in Datadog — instead of clicking in the UI |
| `deprecated/shell-scripts/` | Old scripts (ignore these) | We use Terraform now — it's cleaner |

---

## 🔥 What to Check in Datadog After Deploying

Open [app.datadoghq.com](https://app.datadoghq.com) and look for:

| Tab | What You'll See | Filter |
|---|---|---|
| **APM → Traces** | Request flowing Java → Python → .NET | `env:k8s-lab` |
| **APM → Services** | Service map of your 3 apps | `env:k8s-lab` |
| **Infrastructure → Containers** | Your pods and resource usage | `cluster:datadog-k8s-lab` |
| **Logs → Explorer** | Every log line with `trace_id` | `env:k8s-lab` |
| **Dashboards** | Application Error Dashboard | Search "Error Dashboard" |
| **Monitors** | CPU and crash-loop alerts | Search `[k8s-lab]` |

---

## 🛠️ Troubleshooting & FAQ

**Q: I'm new to Kubernetes — is this too advanced?**
> Not at all. Every command is explained in the [deploy guide](./deploy-guide.md). You only need to copy-paste and run.

**Q: What is a "trace" in simple terms?**
> When a user clicks a button, that creates one request. If the request goes through 3 apps before responding, a **trace** records the entire journey — including how long each app took.

**Q: Do I need to write tracing code?**
> **No.** Datadog SSI injects tracing automatically. You deploy the app YAML and Datadog does the rest.

**Q: What if something fails?**
> Every step in the [deploy guide](./deploy-guide.md) has a "Verify" section so you know if it worked.

**Q: How do I clean up?**
> Run `cd terraform && terraform destroy` then `kind delete cluster --name datadog-k8s-lab`.

---

## 🛣️ Learning Path: What to Do Next

1. ✅ **Finish this lab** — deploy everything and see traces in Datadog
2. 📖 **Read [GLOSSARY.md](./GLOSSARY.md)** — deepen your understanding of observability terms
3. 🔧 **Modify the apps** — change a label, redeploy, and watch Datadog update in real time
4. 🔔 **Edit Terraform** — change an alert threshold and run `terraform apply`
5. 🌐 **Try it on a real cloud provider** — replace `kind` with EKS, GKE, or AKS

---

## 🤝 Contributing

We welcome contributions! See [CONTRIBUTING.md](./CONTRIBUTING.md) for guidelines.

## 📄 License

[MIT License](./LICENSE)

---

> 💡 **Tip:** If you're ever stuck, every command in this repo is explained line-by-line in [deploy-guide.md](./deploy-guide.md). You don't need to memorize anything — just follow the steps!
