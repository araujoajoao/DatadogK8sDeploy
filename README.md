# Datadog Observability Engineering Project

This project demonstrates how to set up a Kubernetes cluster, deploy Java, .NET, and Python applications, and integrate them with Datadog for observability. The project includes the following components:

- Kubernetes Cluster Setup using kind.
- Datadog Integration for monitoring logs, metrics, and traces.
- Deployment of Applications: Java, .NET, and Python.
- Integration with Middleware: Apache and RabbitMQ.
- Custom Dashboards and Alarms in Datadog.

## Prerequisites
Before starting, ensure you have the following installed:

- **Docker**: For building and running containers.
- **kubectl**: Kubernetes command-line tool.
- **kind**: Kubernetes IN Docker (for local cluster setup).
- **Helm**: Package manager for Kubernetes.
- **Datadog Account**: Create an account at [Datadog](https://www.datadoghq.com/).

## Step 1: Create a Kubernetes Cluster with kind
Create a Kubernetes cluster using kind:

```bash
kind create cluster --config kubernetes/kind-config.yaml
```

Install Calico for networking:

```bash
kubectl apply -f https://docs.projectcalico.org/manifests/calico.yaml
```

## Step 2: Set Up Datadog Agent
Add the Datadog Helm repository:

```bash
helm repo add datadog https://helm.datadoghq.com
helm repo update
```

Install the Datadog Operator:

```bash
kubectl apply -f kubernetes/datadog-secret.yaml 
```




Install the Datadog Agent using Helm:

```bash
helm install datadog-agent -f kubernetes/datadog-values.yaml datadog/datadog
```

## Step 3: Deploy Middleware (Apache and RabbitMQ)
Deploy Apache:

```bash
kubectl apply -f app/apache-deployment.yaml
kubectl apply -f configmap/apache-configmap.yaml
```

Deploy RabbitMQ:

```bash
kubectl apply -f app/rabbitmq-deployment.yaml
kubectl apply -f configmap/rabbitmq-configmap.yaml
```

## Step 4: Build and Deploy Applications
Build Docker images for the applications:

```bash
git clone https://github.com/appoena/datadogpoweruser.git
```

```bash
cd ../java
docker build -t java-app:latest .

cd ../dotnet
docker build -t dotnet-app:latest .

cd ../python
docker build -t python-app:latest .
```

Load the Docker images into the kind cluster:

```bash
kind load docker-image java-app:latest --name datadog-cluster
kind load docker-image dotnet-app:latest --name datadog-cluster
kind load docker-image python-app:latest --name datadog-cluster
```

Tag and push the images to Docker Hub (optional):

```bash
docker tag dotnet-app araujoajoao/dotnet-app:latest
docker tag python-app araujoajoao/python-app:latest
docker tag java-app araujoajoao/java-app:latest
```

Deploy the applications to Kubernetes:

```bash
kubectl apply -f java-app.yaml
kubectl apply -f dotnet-app.yaml
kubectl apply -f python-app.yaml
```

## Step 5: Configure Metrics Collection
Deploy the metrics configuration for each application:

```bash
kubectl apply -f metrics/java-app.yaml
kubectl apply -f metrics/dotnet-app.yaml
kubectl apply -f metrics/python-app.yaml
```

## Step 6: Restart the Cluster (if needed)
If you need to restart the cluster, follow these steps:

Delete the existing cluster:

```bash
kind delete cluster --name datadog-cluster
```

Recreate the cluster and reapply all configurations:

```bash
kind create cluster --config kubernetes/kind-config.yaml
kubectl apply -f https://docs.projectcalico.org/manifests/calico.yaml
kubectl apply -f kubernetes/datadog-secret.yaml
helm install datadog-agent -f kubernetes/datadog-values.yaml datadog/datadog
```

## Step 7: Verify Deployment
Check the status of your pods:

```bash
kubectl get pods
```

Verify that the Datadog Agent is running:

```bash
kubectl get pods | grep datadog-agent
```

Check the logs of the Datadog Agent for any errors:

```bash
kubectl logs <datadog-agent-pod-name>
```

## Step 8: Monitor in Datadog
- **Logs**: Go to the Logs section in Datadog and filter by the service names (`java-app`, `dotnet-app`, `python-app`).
- **Metrics**: Use the Metrics Explorer to view custom metrics from your applications.
- **APM Traces**: Check the APM section to view traces for your applications.
- **Dashboards**: Create custom dashboards in Datadog to monitor error rates, resource usage, and other key metrics.

## Step 9: Set Up Alarms
- **Memory Usage Alarm**: Create a monitor in Datadog that triggers an alarm when a pod exceeds 75% memory usage.
- **Crash Loop Alarm**: Create a monitor that triggers an alarm when a pod enters a crash loop backoff state.

## Troubleshooting
If logs or metrics are not appearing in Datadog, check the logs of the Datadog Agent:

```bash
kubectl logs <datadog-agent-pod-name>
```

Ensure the Datadog Agent is running and has the correct API key configured.
Verify that the applications are exposing metrics and logs correctly.

## Get to the point
This project demonstrates how to set up a Kubernetes cluster, deploy applications, and integrate them with Datadog for observability. By following this guide, you can monitor logs, metrics, and traces for your Java, .NET, and Python applications, and set up alarms for critical events.

For further customization, refer to the [Datadog documentation](https://docs.datadoghq.com/).

## License
This project is licensed under the MIT License. See the LICENSE file for details.
