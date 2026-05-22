# Appoena Observability Lab — k8s-datadog

Kubernetes observability lab deploying Java, Python, and .NET applications on a local [kind](https://kind.sigs.k8s.io/) cluster with full Datadog integration via the **Datadog Operator**.

## What this lab covers

- Kubernetes cluster with kind (1 control-plane + 3 workers)
- Datadog Operator managing the agent DaemonSet and Cluster Agent
- APM traces with automatic instrumentation for Java, Python, and .NET
- Log collection with unified service tagging (`env:mentoria`)
- Infrastructure metrics: Apache, RabbitMQ, Kubernetes, JVM/runtime
- Monitors and dashboard provisioned via Terraform

## Stack

| Component | Image / Version |
|---|---|
| Datadog Agent | `7.78.1` |
| Datadog Cluster Agent | `7.78.1` |
| Java app | `araujoajoao/java-app:latest` (Spring Boot) |
| Python app | `araujoajoao/python-app:latest` (Flask) |
| .NET app | `araujoajoao/dotnet-app:latest` (ASP.NET Core) |
| Apache | `httpd:latest` |
| RabbitMQ | `rabbitmq:management` |

## Quick start

See [appoena-lab-deploy-guide.md](./appoena-lab-deploy-guide.md) for the full validated step-by-step guide.

### Prerequisites

```bash
brew install kind kubectl helm terraform
```

You also need a [Datadog trial account](https://app.datadoghq.com) with an API Key and an App Key.

### Deploy

```bash
# 1. Create the cluster
kind create cluster --config kubernetes/kind-config.yaml --name appoena-lab

# 2. Install the Datadog Operator
helm repo add datadog https://helm.datadoghq.com && helm repo update
helm install datadog-operator datadog/datadog-operator --namespace default

# 3. Create the Datadog secret
kubectl create secret generic datadog-secret \
  --from-literal=api-key=YOUR_API_KEY \
  --from-literal=app-key=YOUR_APP_KEY

# 4. Deploy the Datadog Agent
kubectl apply -f kubernetes/datadog-agent.yaml

# 5. Deploy ConfigMaps, middleware, and apps
kubectl apply -f configmap/
kubectl apply -f app/
kubectl apply -f builds/metrics/

# 6. Provision monitors and dashboard (Terraform)
cd terraform && terraform init
terraform apply -var="datadog_api_key=YOUR_API_KEY" -var="datadog_app_key=YOUR_APP_KEY"
```

## Repository structure

```
kubernetes/
  kind-config.yaml        # Cluster: 1 control-plane + 3 workers
  datadog-agent.yaml      # DatadogAgent CR (v2alpha1) — agent + all features

app/
  apache-deployment.yaml  # Apache with mod_status init container
  apache-service.yaml
  rabbitmq-deployment.yaml
  rabbitmq-service.yaml

configmap/
  apache-configmap.yaml   # Apache log paths + check instances
  rabbitmq-configmap.yaml # RabbitMQ log paths + check instances

builds/metrics/
  java-app.yaml           # Spring Boot — APM + logs, port 8080
  python-app.yaml         # Flask — APM + logs, port 5000
  dotnet-app.yaml         # ASP.NET Core — APM + logs, port 80

terraform/
  providers.tf
  variables.tf
  monitors.tf             # Memory alert + CrashLoopBackOff monitor
  dashboard.tf            # Application Error Dashboard
```

## Datadog UI

| What | Where | Filter |
|---|---|---|
| Cluster | Infrastructure → Kubernetes | `cluster:appoena-lab` |
| APM | APM → Services | `env:mentoria` |
| Logs | Logs → Explorer | `service:(apache OR rabbitmq OR java-app OR python-app OR dotnet-app) env:mentoria` |
| Monitors | Monitors → Manage | `[mentoria]` |
| Dashboard | Dashboards → List | `Application Error Dashboard` |

## Teardown

```bash
cd terraform && terraform destroy \
  -var="datadog_api_key=YOUR_API_KEY" \
  -var="datadog_app_key=YOUR_APP_KEY"

kind delete cluster --name appoena-lab
```

elatório de Troubleshooting: Instrumentação APM e Coleta de Logs no Datadog
1. Objetivo
Implementar monitoramento completo (Traces e Logs) para três microsserviços (Java, Python, .NET) e um servidor Web (Apache) em um cluster Kubernetes local (Kind), garantindo a correlação de dados no Datadog.
2. Fluxo de Instrumentação (O Caminho Feliz)
A estratégia inicial seguiu as melhores práticas de Observabilidade:
•	Unified Service Tagging: Aplicação de labels padrão (env, service, version) em todos os manifestos para garantir correlação.
•	Autodiscovery: Uso de annotations do Datadog (ad.datadoghq.com) para que o Agent mapeasse dinamicamente logs e checks de infraestrutura.
•	Injeção por Admission Controller: Configuração para que o Operator do Datadog injetasse automaticamente os tracers nas aplicações via mutating webhook.
3. Problemas Identificados (Análise de Causa Raiz)
Durante a implementação, encontramos dois problemas críticos que impediam a visualização dos dados:
Problema	Causa Raiz	Sintoma
Ausência de Traces	Falha no Mutating Webhook do Datadog em ambiente Kind. O Control Plane não conseguia rotear o tráfego de volta para os workers para realizar a injeção automática.	Pods subiam sem Init Containers e sem as bibliotecas de tracing injetadas.
Conectividade de Rede	Uso de status.hostIP em manifestos de rede local. Em clusters Kind, esse IP nem sempre é roteável para pods de aplicação internos.	Aplicações tentavam enviar dados para um IP inexistente/inacessível, resultando em timeouts.
4. Soluções Implementadas (Resolução via Troubleshooting)
Para contornar as limitações do ambiente local (Kind), adotamos a técnica de Injeção Manual (Bypass):
	1.	Injeção Via Volume (Sidecar/Init Pattern): Substituímos o webhook automático por initContainers explícitos.
•	Ação: O initContainer baixa a imagem oficial da biblioteca do Datadog e copia os arquivos necessários para um emptyDir compartilhado.
•	Resultado: A biblioteca de tracing passou a residir fisicamente dentro do Pod, eliminando a dependência do webhook.
	2.	Ajuste de Roteamento de Rede:
•	Ação: Alteramos a variável de ambiente DD_AGENT_HOST para o nome de serviço interno do K8s (datadog-agent.default.svc.cluster.local).
•	Resultado: O DNS interno do Kubernetes resolveu o problema de conectividade, permitindo que os pods alcançassem o Agent com sucesso.
	3.	Variáveis de Ambiente de Runtime:
•	Ação: Configuração específica por linguagem (ex: JAVA_TOOL_OPTIONS para Java, PYTHONPATH para Python e CORECLR_PROFILER para .NET) para apontar o interpretador/runtime ao arquivo de trace injetado.
5. Conclusão para a Aula
Este laboratório demonstra que, em troubleshooting, "o que parece automático muitas vezes depende de uma infraestrutura de rede que precisa ser validada". Quando os mecanismos de injeção automática falham (seja por rede, permissões ou limitações de ambiente), a capacidade de configurar o processo de injeção manualmente ("na mão") é o diferencial que permite manter a observabilidade funcionando.
Dica para a apresentação: Enfatize que o comando kubectl describe pod foi a ferramenta chave para diagnosticar a ausência dos Init Containers, o que provou que a injeção automática estava sendo ignorada pelo cluster.
