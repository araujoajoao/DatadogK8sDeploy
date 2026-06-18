# Relatório de Validação — README.md vs appoena-lab-deploy-guide.md

**Data da verificação:** 2026-05-29
**Repositório:** `/Volumes/Macintosh HD 2/labs/k8s-datadog`
**Escopo:** Comparar o README.md (Quick Start) com o guia passo a passo (appoena-lab-deploy-guide.md) e verificar existência dos arquivos referenciados.

---

## 1. Status Geral

**O README.md precisa de ajustes — 2 problemas críticos identificados.**

O README está bem estruturado como Quick Start e a maioria das instruções está correta. Porém, foram encontradas duas discrepâncias classificadas como **ERRO** que podem impedir o funcionamento do deploy ou causar confusão no usuário: (a) ausência do `--namespace default` na criação do secret e (b) ausência do aviso para não aplicar `datadog-secret.yaml`.

---

## 2. Verificação de Existência dos Arquivos

Todos os arquivos referenciados no README existem no repositório:

| Arquivo referenciado | Existe? | Caminho verificado |
|---|---|---|
| `kubernetes/kind-config.yaml` | ✅ | Presente |
| `kubernetes/datadog-agent.yaml` | ✅ | Presente |
| `kubernetes/datadog-secret.yaml` | ✅ | Presente (template) |
| `configmap/apache-configmap.yaml` | ✅ | Presente |
| `configmap/rabbitmq-configmap.yaml` | ✅ | Presente |
| `configmap/java-logging-config.yaml` | ✅ | Presente |
| `configmap/python-logging-patch.yaml` | ✅ | Presente |
| `app/apache-deployment.yaml` | ✅ | Presente |
| `app/apache-service.yaml` | ✅ | Presente |
| `app/rabbitmq-deployment.yaml` | ✅ | Presente |
| `app/rabbitmq-service.yaml` | ✅ | Presente |
| `builds/metrics/java-app.yaml` | ✅ | Presente |
| `builds/metrics/python-app.yaml` | ✅ | Presente |
| `builds/metrics/dotnet-app.yaml` | ✅ | Presente |
| `builds/metrics/services.yaml` | ✅ | Presente |
| `terraform/providers.tf` | ✅ | Presente |
| `terraform/variables.tf` | ✅ | Presente |
| `terraform/monitors.tf` | ✅ | Presente |
| `terraform/dashboard.tf` | ✅ | Presente |

**Nenhum arquivo referenciado está faltando.**

---

## 3. Comparação Passo a Passo (Quick Start vs Deploy Guide)

### Passo 0 — Start LoadBalancer Controller
- **README:** `sudo cloud-provider-kind`
- **Deploy Guide:** Mesma instrução
- **Resultado:** ✅ OK (sem discrepância — INFO)

---

### Passo 1 — Create the Cluster
- **README:** `kind create cluster --config kubernetes/kind-config.yaml --name appoena-lab`
- **Deploy Guide:** Mesma instrução
- **Resultado:** ✅ OK (sem discrepância)

---

### Passo 2 — Install Datadog Operator
- **README:**
  ```bash
  helm repo add datadog https://helm.datadoghq.com && helm repo update
  helm install datadog-operator datadog/datadog-operator --namespace default
  ```
- **Deploy Guide:** Mesmas instruções
- **Resultado:** ✅ OK (sem discrepância)

---

### Passo 3 — Create Datadog Secret

**❌ ERRO — Flag `--namespace default` faltando no README**

- **README:**
  ```bash
  kubectl create secret generic datadog-secret \
    --from-literal=api-key=YOUR_API_KEY \
    --from-literal=app-key=YOUR_APP_KEY
  ```

- **Deploy Guide:**
  ```bash
  kubectl create secret generic datadog-secret \
    --from-literal=api-key=YOUR_API_KEY \
    --from-literal=app-key=YOUR_APP_KEY \
    --namespace default
  ```

**Problema:** Sem `--namespace default`, o secret será criado no namespace atual do contexto do kubectl. O `DatadogAgent` (datadog-agent.yaml) referencia o secret `datadog-secret` sem especificar namespace, o que faz o Cluster Agent procurar no namespace `default` — onde o `DatadogAgent` está部署ado. Se o secret for criado em outro namespace (por exemplo, `apps`), o Datadog Agent não conseguirá encontrá-lo e a instrumentação falhará silenciosamente.

**Recomendação:** Adicionar `--namespace default` ao comando do passo 3 no README.

---

### Passo 4 — Deploy Datadog Agent
- **README:** `kubectl apply -f kubernetes/datadog-agent.yaml`
- **Deploy Guide:** Mesma instrução
- **Resultado:** ✅ OK (sem discrepância)

---

### Passo 5 — Deploy ConfigMaps (default namespace)
- **README:**
  ```bash
  kubectl apply -f configmap/apache-configmap.yaml
  kubectl apply -f configmap/rabbitmq-configmap.yaml
  ```
- **Deploy Guide:** Mesmas instruções
- **Resultado:** ✅ OK (sem discrepância)

---

### Passo 6 — Create apps namespace and deploy app ConfigMaps
- **README:**
  ```bash
  kubectl create namespace apps
  kubectl apply -f configmap/java-logging-config.yaml
  kubectl apply -f configmap/python-logging-patch.yaml
  ```
- **Deploy Guide:** Mesmas instruções
- **Resultado:** ✅ OK (sem discrepância)

**Nota de consistência verificada nos arquivos:**
- `java-logging-config.yaml` → `namespace: apps` ✅
- `python-logging-patch.yaml` → `namespace: apps` ✅

---

### Passo 7 — Deploy Apache and RabbitMQ

**⚠️ ALERTA — Uso de `kubectl apply -f app/` ao invés de aplicar individuais**

- **README:** `kubectl apply -f app/`
- **Deploy Guide:**
  ```bash
  kubectl apply -f app/apache-deployment.yaml
  kubectl apply -f app/apache-service.yaml
  kubectl apply -f app/rabbitmq-deployment.yaml
  kubectl apply -f app/rabbitmq-service.yaml
  ```

**Análise:** O comando `kubectl apply -f app/` é funcionalmente equivalente e tecnicamente correto — o Kubernetes preserva a ordem dos objetos dentro de um arquivo ou diretório quando necessário (Services antes de Deployments não é uma exigência do Kubernetes, mas é uma boa prática). Isso é uma **INFO**, acceptable em um Quick Start. No entanto, caso o `app/apache-deployment.yaml` ou outro recurso tenha dependência implícita de ordering, o deploy guide prefere ser explícito.

**Recomendação:** Manter como está, mas considerar adicionar uma nota de que a ordem dos arquivos no diretório é respeitada pelo kubectl.

---

### Passo 8 — Deploy apps and services

**⚠️ ALERTA — Uso de `kubectl apply -f builds/metrics/` ao invés de individuais**

- **README:** `kubectl apply -f builds/metrics/`
- **Deploy Guide:**
  ```bash
  kubectl apply -f builds/metrics/java-app.yaml
  kubectl apply -f builds/metrics/python-app.yaml
  kubectl apply -f builds/metrics/dotnet-app.yaml
  kubectl apply -f builds/metrics/services.yaml
  ```

**Análise:** Mesmo caso do passo 7. Funcionalmente equivalente. Acceptable para Quick Start conforme as instruções de validação. Classificado como **INFO**.

---

### Passo 9 — Provision Terraform monitors and dashboard
- **README:**
  ```bash
  cd terraform && terraform init
  terraform apply -var="datadog_api_key=YOUR_API_KEY" -var="datadog_app_key=YOUR_APP_KEY"
  ```
- **Deploy Guide:**
  ```bash
  cd terraform
  terraform init
  terraform apply \
    -var="datadog_api_key=YOUR_API_KEY" \
    -var="datadog_app_key=YOUR_APP_KEY"
  ```
- **Resultado:** ✅ OK (sem discrepância — apenas diferença de formatação)

---

## 4. Avisos Importantes

### 4.1 Aviso "não aplicar datadog-secret.yaml"

**❌ ERRO — Aviso ausente no README**

O deploy guide contém esta nota explicita:

> Do **not** apply `kubernetes/datadog-secret.yaml` directly — it contains placeholder values only.

O README **não menciona esse aviso em nenhum lugar**. O arquivo `datadog-secret.yaml` existe no repositório e contém valores em Base64 de exemplo (não as chaves reais do usuário). Se o usuário seguir o Quick Start e, por curiosidade ou hábito, aplicar esse arquivo, o Datadog Operator receberá credenciais inválidas e a instrumentação falhará de forma silenciosa.

**Recomendação:** Adicionar uma nota no Passo 3 do Quick Start, logo após o comando de criação do secret:
```markdown
> Do not apply `kubernetes/datadog-secret.yaml` directly — it contains placeholder values only.
```

---

### 4.2 Aviso sobre `--namespace default` no secret

**❌ ERRO — Correlacionado ao erro do Passo 3**

O deploy guide menciona explicitamente que `--namespace default` é necessário para que o secret seja encontrado pelo DatadogAgent. O README omite essa flag. O resultado é que o secret pode ser criado no namespace errado. Combinado com a ausência do aviso sobre o datadog-secret.yaml, o usuário pode acaber aplicando o arquivo template em vez de criar o secret corretamente.

---

## 5. Consistência de Conteúdo

### Stack Table
| Item | README | Arquivo real | Status |
|---|---|---|---|
| Datadog Agent | `7.79.0` | `datadog-agent.yaml` → `override.nodeAgent.image.tag: "7.79.0"` | ✅ OK |
| Cluster Agent | `7.79.0` | `datadog-agent.yaml` → `clusterAgent.image.tag: "7.79.0"` | ✅ OK |
| Java app image | `araujoajoao/java-app:latest` | `builds/metrics/java-app.yaml` | ✅ OK |
| Python app image | `araujoajoao/python-app:py311` | `builds/metrics/python-app.yaml` | ✅ OK |
| .NET app image | `araujoajoao/dotnet-app:latest` | `builds/metrics/dotnet-app.yaml` | ✅ OK |
| Apache | `httpd:latest` | `app/apache-deployment.yaml` | ✅ OK |
| RabbitMQ | `rabbitmq:management` | `app/rabbitmq-deployment.yaml` | ✅ OK |

### Namespace Layout
| Namespace | README diz | Arquivos reais | Status |
|---|---|---|---|
| `default` | Datadog agent, Cluster Agent, Apache, RabbitMQ | datadog-agent.yaml (namespace: default), apache (sem namespace = default), rabbitmq (sem namespace = default) | ✅ OK |
| `apps` | java-app, python-app, dotnet-app e Services | java-app.yaml, python-app.yaml, dotnet-app.yaml, services.yaml (todos namespace: apps) | ✅ OK |
| SSI disabled | `kube-system` e `default` | `datadog-agent.yaml` → `disabledNamespaces: [kube-system, default]` | ✅ OK |

### Traffic Endpoints
O README lista IPs específicos (192.168.97.6/7/8). O deploy guide não lista IPs fixos e adverte que "IPs may differ on your machine". O README também faz a mesma ressalva. A informação no README é correta como exemplo. A omissão do deploy guide em não listar IPs fixos é coerente.

### Distributed Trace Flow
O fluxo `java-app /greeting → python-flask:8082/api/dotnet → dotnet-app/weatherforecast` está correto e bate com:
- `builds/metrics/services.yaml`: `python-flask` tem porta `8082 → targetPort: 5000` ✅
- `GreetingController` mentioned in deploy guide hardcodes `http://python-flask:8082/api/dotnet` ✅

### APM annotations
O README lista os três formatos de annotation (java-lib, python-lib, dotnet-lib) e o datadog-agent.yaml confirma que SSI está habilitado com `instrumentation: enabled: true`.

### Log-Trace Correlation
A descrição do README sobre o campo `dd.trace_id` está correta para todos os três apps. A menção de que a Python app precisa do `import ddtrace.bootstrap.sitecustomize` está presente no README (seção "Python note") e é confirmada pelo `python-logging-patch.yaml`.

### Datadog UI filters
A tabela de filtros Datadog UI do README está alinhada com a do deploy guide. Todos os filtros (`cluster:appoena-lab`, `env:mentoria`, etc.) batem.

### Repository Structure
A estrutura listada no README está completa e reflete fielmente os arquivos existentes no repositório. A descrição do `services.yaml` está especialmente correta ("including python-flask alias (ports 80/5000/8082→5000)").

---

## 6. Resumo das Discrepâncias

| # | Severidade | Localização (README) | Descrição |
|---|---|---|---|
| 1 | **ERRO** | Passo 3 — Quick Start | Falta `--namespace default` no `kubectl create secret generic` |
| 2 | **ERRO** | Passo 3 — Quick Start | Ausência do aviso "Do not apply `kubernetes/datadog-secret.yaml`" |
| 3 | **INFO** | Passo 7 | Uso de `kubectl apply -f app/` vs. aplicar arquivos individuais — funcionalmente equivalente, aceitável em Quick Start |
| 4 | **INFO** | Passo 8 | Uso de `kubectl apply -f builds/metrics/` vs. aplicar arquivos individuais — funcionalmente equivalente, aceitável em Quick Start |

---

## 7. Recomendações de Correção

### Correção 1 (obrigatória) — Adicionar `--namespace default` ao Passo 3

No arquivo `README.md`, alterar:

```markdown
# 3. Create the Datadog secret
kubectl create secret generic datadog-secret \
  --from-literal=api-key=YOUR_API_KEY \
  --from-literal=app-key=YOUR_APP_KEY
```

Para:

```markdown
# 3. Create the Datadog secret
kubectl create secret generic datadog-secret \
  --from-literal=api-key=YOUR_API_KEY \
  --from-literal=app-key=YOUR_APP_KEY \
  --namespace default

> Do not apply `kubernetes/datadog-secret.yaml` directly — it contains placeholder values only.
```

### Correção 2 (opcional) — Padronizar Passos 7 e 8

Manter os comandos agregados (`kubectl apply -f app/` e `kubectl apply -f builds/metrics/`) por serem mais concisos e funcionais. Se quiser ser mais explícito como o deploy guide, substituir por comandos individuais.

---

## 8. Conclusão

O README.md está **majoritariamente correto** e bem escrito. A estrutura, os paths, os nomes de arquivos, as versões de imagens, os filtros do Datadog UI e a descrição da arquitetura distribuída estão todos alinhados com o deploy guide e com os arquivos reais do repositório.

As duas correções necessárias são simples e de baixo risco, mas são importantes para evitar que o secret seja criado no namespace errado ou que o usuário aplique o arquivo de template placeholder em vez de criar o secret manualmente.

Com as duas correções do Passo 3 aplicadas, o README.md estará pronto para uso como Quick Start confiável.