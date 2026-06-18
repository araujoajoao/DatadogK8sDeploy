# Exploration Summary: k8s-datadog Lab

## 1. Repository Contents

### Directories:
- `app/` - Kubernetes manifests for Apache and RabbitMQ
- `builds/` - Contains metrics subdirectory with application deployments
- `configmap/` - ConfigMap definitions for logging and configuration
- `kubernetes/` - Kind cluster config, Datadog agent manifests
- `terraform/` - Terraform files for Datadog monitors and dashboard
- `.kimchi/` - Contains documentation (where this summary will be stored)
- `.trunk/` - Trunk CI configuration (linting, formatting)
- `.claude/` - Claude AI settings

### Key Files:
- `README.md` - Main documentation with lab overview and quick start
- `appoena-lab-deploy-guide.md` - Detailed step-by-step deployment guide
- `populate.sh` - Script to populate data (likely for testing)
- `deploy-validation-*.txt` - Validation output from previous deployments
- Various YAML files for Kubernetes resources

## 2. Kubernetes Manifests & Deployment Configurations

### Kind Cluster Configuration:
- `kubernetes/kind-config.yaml` - Defines a kind cluster with 1 control-plane + 3 worker nodes

### Datadog Deployment:
- `kubernetes/datadog-agent.yaml` - DatadogAgent CR (v2alpha1) with APM SSI enabled
- `kubernetes/datadog-secret.yaml` - Template for Datadog API/App secret (not to be applied directly)
- `kubernetes/populate-cronjob.yaml` - CronJob for populating test data

### Application Deployments:
#### Default Namespace:
- `app/apache-deployment.yaml` & `app/apache-service.yaml` - Apache web server
- `app/rabbitmq-deployment.yaml` & `app/rabbitmq-service.yaml` - RabbitMQ message broker

#### Apps Namespace (via builds/metrics/):
- `builds/metrics/java-app.yaml` - Java Spring Boot application
- `builds/metrics/python-app.yaml` - Python Flask application  
- `builds/metrics/dotnet-app.yaml` - .NET ASP.NET Core application
- `builds/metrics/services.yaml` - Services for all apps including `python-flask` alias

### ConfigMaps:
- `configmap/apache-configmap.yaml` - Apache configuration reference
- `configmap/rabbitmq-configmap.yaml` - RabbitMQ configuration reference
- `configmap/java-logging-config.yaml` - Logback JSON pattern for Java app
- `configmap/python-logging-patch.yaml` - Flask entrypoint with ddtrace bootstrap

## 3. Infrastructure Type

The lab uses **kind (Kubernetes IN Docker)** as explicitly stated in:
- README.md: "Kubernetes observability lab running Java, Python, and .NET applications on a local [kind](https://kind.sigs.k8s.io/) cluster"
- `kubernetes/kind-config.yaml` - Kind cluster configuration file
- Deployment guide mentions `kind create cluster`

## 4. Dockerfiles & Build Scripts

**No Dockerfiles found** in the repository. The lab uses pre-built container images:
- Java app: `araujoajoao/java-app:latest`
- Python app: `araujoajoao/python-app:py311`
- .NET app: `araujoajoao/dotnet-app:latest`
- Apache: `httpd:latest`
- RabbitMQ: `rabbitmq:management`

The `populate.sh` script exists but appears to be for populating test data rather than building images.

## 5. Terraform Files

Located in `/terraform/` directory:
- `providers.tf` - Datadog provider configuration (~v3.0)
- `variables.tf` - Variables for API key, app key, notification email, environment
- `monitors.tf` - Pod memory alert and CrashLoopBackOff monitor definitions
- `dashboard.tf` - Application Error Dashboard provisioning

These files provision Datadog monitors and dashboard via Terraform.

## 6. CI/CD Workflows & Deployment Scripts

**No CI/CD workflow files found** (no GitHub Actions, GitLab CI, Jenkinsfile, etc.).

**Deployment scripts:**
- `populate.sh` - Makes API calls to deployed applications to generate traffic/data
- The deployment process is documented in README.md and appoena-lab-deploy-guide.md as manual steps involving:
  1. `cloud-provider-kind` (for LoadBalancer IPs)
  2. `kind create cluster`
  3. Helm install of Datadog Operator
  4.kubectl apply for various manifests
  5. Terraform apply for monitors/dashboard

## 7. README & Deployment Instructions

**Primary README:** `/README.md` contains:
- Lab overview and what it covers
- Stack description with image versions
- Namespace layout explanation
- APM details with Single Step Instrumentation
- Distributed trace flow diagram
- Traffic endpoints and LoadBalancer information
- Log-trace correlation details
- Quick start guide with prerequisites and step-by-step deployment
- Teardown instructions

**Secondary Guide:** `/appoena-lab-deploy-guide.md` provides a more detailed, validated step-by-step deployment guide.

## Summary

This repository contains a complete observability lab demonstrating Datadog's capabilities in a Kubernetes environment. It features:
- A local kind cluster with 4 nodes
- Datadog Operator and Agent with Single Step Instrumentation
- Three instrumented applications (Java, Python, .NET) showing distributed tracing
- Supporting services (Apache, RabbitMQ)
- Log trace correlation across all services
- Terraform-provisioned Datadog monitors and dashboard
- Comprehensive documentation for deployment and teardown

The lab is designed to be run locally with kind and requires a Datadog account for full functionality.
