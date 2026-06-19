# Observability Glossary for Beginners

This glossary explains every technical term used in this lab, in plain English.

---

## A

### APM (Application Performance Monitoring)
Watching how your applications perform in real time — how fast they respond, how often they fail, and where the bottlenecks are. Think of it like a fitness tracker for your code.

---

## C

### Container
A lightweight, isolated environment that packages your application and everything it needs to run (code, runtime, libraries) into a single unit. Multiple containers run on the same machine without interfering with each other.

### Container Orchestration
Automatically managing containers — starting them, stopping them, scaling them up or down, and making sure they stay healthy. **Kubernetes** is the most popular orchestrator.

---

## D

### Datadog
A cloud monitoring and observability platform. It collects your metrics, logs, and traces and displays them in dashboards and alerts.

### Distributed Tracing
Following a single user request as it travels through multiple services. Each "hop" is recorded, so you can see the full journey and identify which service is slow. The entire journey is given one **trace ID**.

---

## H

### Helm
A package manager for Kubernetes. Instead of writing hundreds of lines of YAML by hand, you install pre-packaged "charts" (like `datadog-operator`) with one command.

---

## I

### Infrastructure Monitoring
Watching the underlying systems your apps run on — servers, load balancers, message brokers (like RabbitMQ), web servers (like Apache), databases. This is different from **APM**, which watches the applications themselves.

---

## K

### kind (Kubernetes in Docker)
A tool that runs a full Kubernetes cluster inside Docker containers on your laptop. It's free, fast, and perfect for learning.

### kubectl
The command-line tool you use to talk to Kubernetes. You use it to deploy apps, check logs, inspect resources, and debug problems.

### Kubernetes (K8s)
An open-source system for automating the deployment, scaling, and management of containerized applications. It handles the hard parts — restarting crashed apps, load balancing traffic, and scaling up when demand increases.

---

## L

### Log-Trace Correlation
Every log line carries the same **trace ID** as the APM trace, so you can jump from a log entry directly to the full distributed trace that generated it. This makes debugging much faster.

### Logs
Timestamped text records of events in your application. Example: `ERROR: could not connect to database at 2026-06-18 14:23:01`.

---

## M

### Metric
A numeric measurement collected over time. Examples: CPU usage (%), memory consumption (MB), request latency (ms), error rate (errors/second).

### Monitor (in Datadog)
An automated rule that watches a metric and sends an alert when something goes wrong. Example: "If pod memory usage exceeds 98% for 5 minutes, email the team."

---

## N

### Namespace
A virtual partition inside a Kubernetes cluster. Resources in one namespace are isolated from resources in another. In this lab, we use `datadog` for the agent, `default` for infrastructure, and `apps` for the services.

---

## O

### Observability
The ability to understand what a system is doing by examining its outputs — **metrics**, **logs**, and **traces**. The word comes from "observe": you observe the system from the outside to understand its internal state.

### Operator (Kubernetes)
A custom controller that automates the lifecycle of complex applications. In this lab, the **Datadog Operator** automatically deploys and manages the Datadog Agent and Cluster Agent.

---

## P

### Pod
The smallest deployable unit in Kubernetes. A pod usually contains one container (sometimes more). Your apps run inside pods.

### Polyglot
Using multiple programming languages together. This lab uses Java (Spring), Python (Flask), and .NET (C#) in the same architecture.

---

## S

### SSI (Single Step Instrumentation)
A Datadog feature that automatically injects tracing and monitoring libraries into your applications at deployment time. You write **zero** instrumentation code — Datadog does it for you via a Kubernetes admission webhook.

### Service Map
A visual diagram showing how your services connect and depend on each other. Datadog generates this automatically from your traces.

### Single Step Instrumentation
See **SSI**.

---

## T

### Terraform
An infrastructure-as-code tool. You write configuration files that describe what you want (e.g., "a Datadog monitor that fires at 98% memory"), and Terraform creates it for you. It also tracks changes and can destroy everything cleanly.

### Trace
A record of a single request's journey through your system. A trace contains multiple **spans** — one span for each service the request touches.

### Trace ID
A unique identifier assigned to a request when it enters your system. Every service that handles the request includes this ID in its logs and traces, allowing you to follow the request across the entire architecture.

---

## Y

### YAML
A human-readable data format used for configuration files. Kubernetes and Terraform both use YAML extensively. It's based on indentation (like Python).

```yaml
# Example YAML
apiVersion: v1
kind: Pod
metadata:
  name: my-pod
```
