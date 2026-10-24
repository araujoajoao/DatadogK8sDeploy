# Laboratório de Observabilidade com Datadog e Kubernetes

[![English](https://img.shields.io/badge/📖_Language-🇺🇸_English-lightgrey?style=for-the-badge)](./README.md) [![Português](https://img.shields.io/badge/🇧🇷_Idioma-Português_(PT--BR)_(Ativo)-2ea44f?style=for-the-badge)](#)

[![Validate](https://github.com/araujoajoao/DatadogK8sDeploy/actions/workflows/validate.yml/badge.svg)](https://github.com/araujoajoao/DatadogK8sDeploy/actions/workflows/validate.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Terraform](https://img.shields.io/badge/terraform-%235835CC.svg?style=flat&logo=terraform&logoColor=white)](https://www.terraform.io/)
[![Kubernetes](https://img.shields.io/badge/kubernetes-%23326ce5.svg?style=flat&logo=kubernetes&logoColor=white)](https://kubernetes.io/)

> 👶 **Feito para Iniciantes do Absoluto Zero (Sem experiência prévia com Kubernetes ou Datadog):**
> Aprenda **observabilidade na prática** — como monitorar, rastrear e diagnosticar microsserviços modernos — utilizando o **Datadog** em um **cluster local Kubernetes 100% gratuito** no seu próprio computador. Sem surpresas na fatura da nuvem (custo $0), sem comandos complicados e sem precisar escrever uma única linha de código de instrumentação!

---

## 🆕 Novo em Observabilidade? Comece por aqui!

**Observabilidade** significa entender exatamente o que o seu sistema está fazendo através da análise de **traces (rastros)**, **logs (registros)** e **métricas** — em vez de tentar adivinhar quando algo quebra.

Aplicações modernas são compostas por dezenas de pequenos serviços conversando entre si. Quando ocorre uma lentidão ou falha, você precisa de 3 tipos de sinais para descobrir o motivo em segundos:

- 📊 **Métricas** — números medidos ao longo do tempo (uso de CPU %, consumo de memória, taxa de requisições por segundo, taxa de erros).
- 📝 **Logs** — mensagens de texto registradas com data e hora (`ERROR: falha ao conectar com o banco de dados`).
- 🔗 **Traces (Rastreamento Distribuído)** — o histórico completo do caminho que uma requisição percorre ao passar por múltiplos serviços, mostrando exatamente quanto tempo cada etapa demorou e onde ocorreu a falha.

Este laboratório ensina você a coletar esses três sinais automaticamente em um cluster local, **mesmo que você nunca tenha tocado em Kubernetes ou Datadog antes**.

---

### O que você vai aprender

Ao concluir este laboratório, você saberá:

1. ✅ Como o Kubernetes executa aplicativos em containers e como namespaces organizam recursos
2. ✅ O que é **APM (Application Performance Monitoring)** e como ele detecta gargalos
3. ✅ O que é **rastreamento distribuído** — acompanhando uma requisição entre Java, Python e .NET com o **mesmo Trace ID**
4. ✅ Como **correlacionar logs com traces** — clicar em um erro de log e ir direto para o trace correspondente
5. ✅ Como monitorar infraestrutura (servidor web Apache e mensageria RabbitMQ)
6. ✅ Como o **Datadog SSI (Single Step Instrumentation)** injeta bibliotecas de tracing automaticamente, sem alterar o código-fonte
7. ✅ Como definir alertas e painéis visuais como código usando o **Terraform**

---

## 🎯 Por que fazer este laboratório?

A maioria dos tutoriais de observabilidade assume que você já domina Kubernetes, redes e arquitetura distribuída. **Este laboratório não assume nada disso.**

Aqui você vai:
- 🏗️ **Subir** um cluster local gratuito e leve em menos de 2 minutos usando o [kind](https://kind.sigs.k8s.io/)
- 🔗 **Rastrear** requisições entre **Java, Python e .NET** de ponta a ponta
- 📝 **Ver logs com ID de trace automático** em cada linha gerada
- 📊 **Visualizar métricas de infraestrutura** (RabbitMQ e Apache)
- 🔔 **Criar alertas automáticos** com infraestrutura como código (Terraform)
- ⚡ **Usar instrumentação com zero esforço manual** graças ao Datadog SSI

* **Custo:** R$ 0,00 — roda 100% no seu próprio computador.
* **Tempo estimado:** ~25 a 30 minutos.
* **Pré-requisitos de conhecimento:** Nenhum. Cada comando é detalhado passo a passo.

---

## 📚 Conceitos Essenciais para Iniciantes

| Termo | O que significa em português claro | O que faremos no Lab |
|---|---|---|
| **APM** | Monitoramento de performance da aplicação — tempos de resposta, lentidão e erros | Ver os traces de cada chamada no Datadog |
| **Rastreamento Distribuído** | Acompanhar uma requisição enquanto ela pula de um serviço para outro | Ver uma requisição ir de Java → Python → .NET com o **mesmo Trace ID** |
| **Single Step Instrumentation (SSI)** | O Datadog injeta as bibliotecas de tracing nos pods automaticamente — você não altera o código | Uma simples configuração no Helm habilita para todos os apps |
| **Correlação Log-Trace** | Cada linha de log ganha o mesmo `trace_id` do APM | Pular de um log de erro direto para o ponto exato da lentidão |
| **Métricas** | Dados numéricos ao longo do tempo — consumo de memória, CPU, tamanho de fila | Monitorar a profundidade de fila do RabbitMQ e requisições do Apache |
| **Infraestrutura como Código (IaC)** | Criar alertas e painéis através de arquivos de texto declarativos em vez de cliques manuais na interface | Criar monitores e dashboards no Datadog com `terraform apply` |

> 📖 **Quer se aprofundar nos termos?** Consulte o [GLOSSARY.md](./GLOSSARY.md).

---

## 🏗️ Arquitetura do Sistema

```text
┌────────────────────────────────────────────────────────┐
│  Seu Computador (Cluster Kubernetes Local via Kind)    │
│                                                        │
│  ┌──────────────┐          ┌──────────────┐            │
│  │    Apache    │          │   RabbitMQ   │            │
│  │ (Web Server) │          │ (Mensageria) │            │
│  └──────────────┘          └──────────────┘            │
│         ▲                                              │
│         │                                              │
│  ┌──────────────┐          ┌──────────────┐            │
│  │   java-app   │─────────>│  python-app  │───> .NET   │
│  │ (Spring Boot)│          │   (Flask)    │     app    │
│  └──────────────┘          └──────────────┘            │
│                                                        │
│  Toda requisição gera o MESMO Trace ID entre as 3!     │
└────────────────────────────────────────────────────────┘
```

---

## ⚙️ Configuração Pós-Clone: O que Você Precisa Alterar

> [!IMPORTANT]
> **Resumo: Você só precisa editar UM único arquivo: [`.env`](.env).**
> Você **não** precisa de conta pessoal no Docker Hub, **não** precisa compilar nenhum código e **não** precisa alterar nenhum manifesto YAML do Kubernetes. Tudo já vem configurado com imagens públicas oficiais para funcionar de primeira!

### 📋 Matriz de Configuração

| Arquivo / Componente | Variável | Tipo | O que fazer? |
|---|---|---|---|
| **[`.env`](.env)** | `DATADOG_API_KEY` | 🔴 **Obrigatório** | Cole sua chave de API gerada no Datadog |
| **[`.env`](.env)** | `DATADOG_APP_KEY` | 🔴 **Obrigatório** | Cole sua chave de aplicação gerada no Datadog |
| **[`.env`](.env)** | `DATADOG_SITE` | 🟡 **Regional** | Altere apenas se sua conta Datadog estiver fora dos EUA (ex: `datadoghq.eu`, `us3.datadoghq.com`, `us5.datadoghq.com`). Padrão: `datadoghq.com` |
| **[`.env`](.env)** | `NOTIFICATION_EMAIL` | ⚪ **Opcional** | E-mail para receber notificações de alerta (padrão: `notify@example.com`) |
| **[`.env`](.env)** | `ENV` | ⚪ **Opcional** | Tag de ambiente dos recursos (padrão: `k8s-lab`) |
| `builds/metrics/*.yaml` | Aplicações | 🟢 **Não Alterar** | Já configuradas com imagens oficiais (`springio`, `python:3.11-slim`, `mcr.microsoft.com/dotnet`). |
| `app/*.yaml` | Infraestrutura | 🟢 **Não Alterar** | Usa imagens oficiais (`httpd:2.4`, `rabbitmq:3-management`). |
| `kubernetes/*.yaml` | Agente Datadog & SSI | 🟢 **Não Alterar** | Pré-configurado com admission controller para auto-injeção de APM. |
| `terraform/*.tf` | Alertas como Código | 🟢 **Não Alterar** | Lê as chaves diretamente das variáveis de ambiente (`TF_VAR_*`). |
| `src/` | Código-Fonte Poliglota | 🟢 **Não Alterar** | Disponível para estudo e referência. Não é necessário compilar nada para rodar! |

---

### 🔑 Passo a Passo da Configuração

```bash
# 1. Copie o arquivo de exemplo
cp .env.example .env

# 2. Abra o arquivo no seu editor preferido
nano .env   # ou: code .env, vim .env
```

Preencha os valores:
```bash
# 🔴 OBRIGATÓRIO: Obtenha em Datadog -> Organization Settings -> API Keys / Application Keys
DATADOG_API_KEY="sua_chave_api_aqui"
DATADOG_APP_KEY="sua_chave_app_aqui"

# 🟡 REGIONAL: Verifique a URL do seu navegador ao logar no Datadog
# Se for app.datadoghq.com  -> datadoghq.com (padrão dos EUA)
# Se for app.datadoghq.eu   -> datadoghq.eu (Europa)
# Se for app.us3.datadoghq.com -> us3.datadoghq.com
DATADOG_SITE="datadoghq.com"

# ⚪ OPCIONAL: E-mail que receberá os alertas dos monitores
NOTIFICATION_EMAIL="seu-email@exemplo.com"
```

---

## 🚀 Início Rápido (5 Passos)

Copie e cole os blocos abaixo no seu terminal para subir todo o ambiente:

```bash
# Passo 1: Instale as ferramentas (veja Pré-requisitos abaixo)
# Passo 2: Clone e acesse o repositório
git clone https://github.com/araujoajoao/DatadogK8sDeploy.git
cd DatadogK8sDeploy

# Passo 3: Configure suas credenciais (apenas o arquivo .env precisa de edição!)
cp .env.example .env
# Abra o .env, insira suas chaves do Datadog e carregue as variáveis:
source .env

# Passo 4: Crie o cluster Kubernetes local gratuito com o Kind
kind create cluster --config kubernetes/kind-config.yaml --name datadog-k8s-lab

# Passo 5: Faça o deploy do agente Datadog, aplicações e monitores
kubectl create namespace datadog
kubectl create namespace apps
kubectl create secret generic datadog-secret \
  --from-literal=api-key="$DATADOG_API_KEY" \
  --from-literal=app-key="$DATADOG_APP_KEY" \
  -n datadog
kubectl apply -f kubernetes/datadog-confd-configmap.yaml
helm install datadog-agent datadog/datadog \
  -f kubernetes/datadog-values.yaml \
  --set datadog.site="${DATADOG_SITE:-datadoghq.com}" \
  -n datadog
kubectl apply -f configmap/ -f app/ -f builds/metrics/

# Provisione os monitores e o dashboard no Datadog com Terraform
export TF_VAR_datadog_api_key="$DATADOG_API_KEY"
export TF_VAR_datadog_app_key="$DATADOG_APP_KEY"
export TF_VAR_api_url="https://api.${DATADOG_SITE:-datadoghq.com}/"
export TF_VAR_notification_email="${NOTIFICATION_EMAIL:-notify@example.com}"
cd terraform && terraform init && terraform apply -auto-approve && cd ..

# Gere tráfego de requisições para visualizar os traces
./populate.sh
```

🎯 **Esta foi a versão expressa. Para o guia detalhado comando por comando com explicações em profundidade, veja o [deploy-guide.md](./deploy-guide.md).**

---

## ✅ Ferramentas Necessárias (Pré-requisitos)

Você só precisa destas ferramentas instaladas no seu computador. No macOS (via Homebrew):

| Ferramenta | Para que serve | Comando de Instalação |
|---|---|---|
| **kind** | Cria um cluster Kubernetes dentro do Docker | `brew install kind` |
| **kubectl** | Linha de comando para interagir com o Kubernetes | `brew install kubectl` |
| **helm** | Gerenciador de pacotes para o Kubernetes | `brew install helm` |
| **terraform** | Cria os alertas e dashboards no Datadog como código | `brew install terraform` |
| **Docker** | Necessário para rodar o Kind | `brew install --cask docker` ou OrbStack |

Você também precisa de:
- Uma conta gratuita no [Datadog](https://app.datadoghq.com) (versão trial com 14 dias grátis)
- Sua [API Key e Application Key do Datadog](https://docs.datadoghq.com/account_management/api-app-keys/)

---

## 📂 Estrutura do Projeto

| Pasta | O que contém | O que faz no Lab |
|---|---|---|
| `kubernetes/` | Configurações do cluster Kind e valores do Helm | Sobe o cluster e instala o Agente Datadog com SSI ativo |
| `app/` | Deployments do Apache e RabbitMQ | Serviços de suporte e mensageria monitorados |
| `builds/metrics/` | Manifestos das aplicações Java, Python e .NET | Os microsserviços que você irá rastrear e observar |
| `configmap/` | Configurações de logging e servidores | Garante a injeção do trace ID nos logs |
| `terraform/` | Monitores e Dashboard em código | Cria alertas de CPU, falhas de pods e dashboard automaticamente |
| `src/` | Código-fonte completo em Java, Python, C#, Node e PHP | Código original para quem quiser inspecionar como as APIs funcionam |
| `scripts/` | Utilitários (como `build-images.sh`) | Scripts para construir imagens localmente caso queira customizar |

---

## 🔥 O que conferir no Datadog após o Deploy

Acesse [app.datadoghq.com](https://app.datadoghq.com) (ou o domínio da sua região) e explore:

| Aba no Datadog | O que você vai ver | Filtro sugerido |
|---|---|---|
| **APM → Traces** | O fluxo completo da requisição: Java → Python → .NET | `env:k8s-lab` |
| **APM → Service Catalog** | O mapa de dependência visual dos seus microsserviços | `env:k8s-lab` |
| **Infrastructure → Containers** | Todos os seus pods, consumo de CPU e memória em tempo real | `cluster:datadog-k8s-lab` |
| **Logs → Explorer** | Cada linha de log contendo automaticamente o `trace_id` clicável | `env:k8s-lab` |
| **Dashboards** | Painel "Application Error Dashboard" criado via Terraform | Busque por `Error Dashboard` |
| **Monitors** | Alertas de memória alta e CrashLoopBackOff | Busque por `[k8s-lab]` |

---

## 🛠️ Perguntas Frequentes (FAQ)

**P: Sou novo em Kubernetes e Docker — vou conseguir acompanhar?**
> **Sim!** O laboratório foi desenvolvido especificamente para iniciantes. Cada comando do [deploy-guide.md](./deploy-guide.md) possui explicações didáticas em linguagem simples.

**P: Preciso criar conta no Docker Hub ou fazer build das imagens?**
> **Não.** Todas as aplicações utilizam imagens públicas oficiais dos mantenedores das linguagens. Nenhuma compilação ou login no Docker Hub é necessário.

**P: Quais arquivos eu preciso alterar depois de clonar o repositório?**
> **Apenas o `.env`!** Basta copiar `.env.example` para `.env` e inserir sua `DATADOG_API_KEY` e `DATADOG_APP_KEY`. Nada nos arquivos YAML ou Terraform precisa ser editado.

**P: E se a minha conta Datadog for da Europa (`datadoghq.eu`) ou de outra região?**
> Basta alterar `DATADOG_SITE=datadoghq.eu` no seu arquivo `.env`. O comando do Helm e o Terraform usarão essa variável automaticamente.

**P: O que é um "trace" em palavras simples?**
> Quando um usuário clica em um botão, uma requisição é disparada. Se essa requisição passar por 3 aplicações diferentes antes de responder, o **trace** grava todo esse caminho como uma linha do tempo, mostrando quanto tempo cada serviço levou e se houve erros.

**P: Preciso escrever código para instrumentar minhas aplicações?**
> **Não.** O Datadog SSI (Single Step Instrumentation) injeta os agentes de APM automaticamente em tempo de execução dentro dos containers.

**P: Como faço para remover tudo e limpar meu computador ao final?**
> Basta rodar: `cd terraform && terraform destroy -auto-approve` e depois `kind delete cluster --name datadog-k8s-lab`.

---

## 🤝 Contribuições

Contribuições são muito bem-vindas! Consulte o guia de contribuição em [CONTRIBUTING.md](./CONTRIBUTING.md) para entender nossas boas práticas de branching e pull requests.

## 📄 Licença

Distribuído sob a licença [MIT](./LICENSE).
