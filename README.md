# Datadog Observability Engineering Project

This project demonstrates how to set up a Kubernetes cluster, deploy Java, .NET, and Python applications, and integrate them with Datadog for observability using the **Datadog Operator**.

- Kubernetes Cluster Setup using kind.
- Datadog integration via the Datadog Operator for logs, metrics, and traces.
- Deployment of Applications: Java, .NET, and Python.
- Integration with Middleware: Apache and RabbitMQ.
- Custom Dashboards and Alarms in Datadog.

## Prerequisites

- **Docker**: For building and running containers.
- **kubectl**: Kubernetes command-line tool.
- **kind**: Kubernetes IN Docker (for local cluster setup).
- **Helm**: Used only to install the Datadog Operator itself.
- **Datadog Account**: Create an account at [Datadog](https://www.datadoghq.com/).

## Step 1: Create a Kubernetes Cluster with kind

```bash
kind create cluster --config kubernetes/kind-config.yaml
kubectl apply -f https://docs.projectcalico.org/manifests/calico.yaml
```

## Step 2: Create the Datadog Secret

Create the secret with your real API and App keys (do not commit this file with real credentials):

```bash
kubectl create secret generic datadog-secret \
  --from-literal=api-key=<YOUR_DATADOG_API_KEY> \
  --from-literal=app-key=<YOUR_DATADOG_APP_KEY>
```

## Step 3: Install the Datadog Operator

```bash
helm repo add datadog https://helm.datadoghq.com
helm repo update
helm install datadog-operator datadog/datadog-operator
```

Wait for the operator to be ready:

```bash
kubectl wait pod --selector=app.kubernetes.io/name=datadog-operator \
  --for=condition=Ready --timeout=60s
```

## Step 4: Deploy the Datadog Agent

```bash
kubectl apply -f kubernetes/datadog-agent.yaml
```

Verify the agent pods are running:

```bash
kubectl get datadogagent datadog
kubectl get pods | grep datadog
```

## Step 5: Deploy Middleware (Apache and RabbitMQ)

```bash
kubectl apply -f app/apache-deployment.yaml
kubectl apply -f app/rabbitmq-deployment.yaml
kubectl apply -f configmap/apache-configmap.yaml
kubectl apply -f configmap/rabbitmq-configmap.yaml
```

## Step 6: Build and Deploy Applications

Clone the application source code:

```bash
git clone https://github.com/appoena/datadogpoweruser.git
```

Build and load images into the kind cluster:

```bash
docker build -t java-app:latest <path-to-java-source>
docker build -t dotnet-app:latest <path-to-dotnet-source>
docker build -t python-app:latest <path-to-python-source>

kind load docker-image java-app:latest --name datadog-cluster
kind load docker-image dotnet-app:latest --name datadog-cluster
kind load docker-image python-app:latest --name datadog-cluster
```

Or pull from Docker Hub (images already pushed):

```bash
kubectl apply -f builds/metrics/java-app.yaml
kubectl apply -f builds/metrics/dotnet-app.yaml
kubectl apply -f builds/metrics/python-app.yaml
```

## Step 7: Verify Deployment

```bash
kubectl get pods
kubectl get datadogagent datadog
kubectl logs -l app.kubernetes.io/component=agent -c agent --tail=50
```

## Step 8: Restart the Cluster (if needed)

```bash
kind delete cluster --name datadog-cluster

kind create cluster --config kubernetes/kind-config.yaml
kubectl apply -f https://docs.projectcalico.org/manifests/calico.yaml
kubectl create secret generic datadog-secret \
  --from-literal=api-key=<YOUR_DATADOG_API_KEY> \
  --from-literal=app-key=<YOUR_DATADOG_APP_KEY>
helm install datadog-operator datadog/datadog-operator
kubectl apply -f kubernetes/datadog-agent.yaml
```

## Step 9: Monitor in Datadog

- **Logs**: Filter by service names `java-app`, `dotnet-app`, `python-app`, `apache`, `rabbitmq`.
- **Metrics**: Use the Metrics Explorer; Java app exposes Prometheus metrics at `:8080/metrics`.
- **APM Traces**: Check the APM section — traces are sent via `DD_AGENT_HOST` (node IP) on port 8126.
- **Dashboards**: Create custom dashboards to monitor error rates, resource usage, and latency.

## Step 10: Set Up Alarms

- **Memory Usage Alarm**: Trigger when a pod exceeds 75% memory usage.
- **Crash Loop Alarm**: Trigger when a pod enters `CrashLoopBackOff`.

## Troubleshooting

```bash
# Check operator logs
kubectl logs -l app.kubernetes.io/name=datadog-operator

# Check agent logs
kubectl logs -l app.kubernetes.io/component=agent -c agent

# Describe the DatadogAgent resource
kubectl describe datadogagent datadog
```

## License

This project is licensed under the MIT License.
