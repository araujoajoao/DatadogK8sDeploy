# Tarefa de Validação: README.md vs appoena-lab-deploy-guide.md

## Contexto
Você deve comparar os dois documentos abaixo e validar se o README.md está alinhado com o passo a passo do deploy guide, verificando também se os comandos/arquivos estão corretos e existem no repositório.

## Documentos
- `/Volumes/Macintosh HD 2/labs/k8s-datadog/README.md` — Quick Start e visão geral
- `/Volumes/Macintosh HD 2/labs/k8s-datadog/appoena-lab-deploy-guide.md` — Guia completo passo a passo validado

## Tarefas

1. **Verificar existência dos arquivos referenciados**:
   - Liste todos os arquivos/paths referenciados no README (ex: `kubernetes/kind-config.yaml`, `configmap/apache-configmap.yaml`, etc.)
   - Verifique se cada um existe no diretório `/Volumes/Macintosh HD 2/labs/k8s-datadog/`

2. **Comparar passo a passo Quick Start (README) vs Deploy Guide**:
   - Para cada passo do Quick Start (0 a 9), compare com o passo equivalente do deploy guide.
   - Identifique discrepâncias: comandos diferentes, flags faltando (ex: `--namespace default` no secret), ordem trocada, comandos equivalentes mas agregados (ex: `kubectl apply -f app/` vs aplicar individualmente).
   - Classifique cada discrepância como:
     - `ERRO` — impede funcionamento ou está incorreto
     - `ALERTA` — incompleto, confuso ou pode causar problema
     - `INFO` — apenas resumo/omissão esperada em um Quick Start

3. **Verificar consistência de conteúdo**:
   - Stack table, Namespace Layout, APM annotations, Distributed Trace Flow, Log-Trace Correlation, Traffic Endpoints, Datadog UI filters, Repository Structure — verificar se batem com o deploy guide e com os arquivos reais.

4. **Verificar se avisos importantes estão presentes**:
   - O deploy guide diz explicitamente "Do not apply kubernetes/datadog-secret.yaml". O README também diz isso?
   - O deploy guide menciona que `--namespace default` é importante para o secret. O README tem isso?

5. **Gerar o relatório**:
   - Escreva um relatório em português (já que o usuário pediu em português) detalhando:
     - Status geral: README está correto? Precisa de ajustes?
     - Lista de discrepâncias encontradas (com localização no README)
     - Recomendações de correção (se houver)
   - Salve o relatório em `/Volumes/Macintosh HD 2/labs/k8s-datadog/.kimchi/docs/validacao-readme.md`

## Notas
- O README é um "Quick Start" e o deploy guide é o guia completo; portanto, algumas simplificações (como não mencionar `kubectl rollout status`) são aceitáveis para o Quick Start.
- `kubectl apply -f app/` é funcionalmente equivalente a aplicar cada yaml individualmente em `app/`.
- O diretório `.kimchi/docs/` deve ser usado para salvar o relatório.
