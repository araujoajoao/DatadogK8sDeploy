#!/usr/bin/env bash
# ==============================================================================
# Build official multi-stage application images locally and load into Kind
# ==============================================================================
set -euo pipefail

CLUSTER_NAME="${1:-datadog-k8s-lab}"

echo "=== Building application images from local official sources ==="

# Check for Docker or Podman
if command -v docker >/dev/null 2>&1; then
  CONTAINER_CLI="docker"
elif command -v podman >/dev/null 2>&1; then
  CONTAINER_CLI="podman"
else
  echo "ERROR: Neither docker nor podman was found in PATH."
  exit 1
fi

echo "Using container engine: $CONTAINER_CLI"

# 1. Build Java App (official Eclipse Temurin + Maven)
echo "--> Building k8s-lab/java-app:latest..."
$CONTAINER_CLI build -t k8s-lab/java-app:latest src/JavaApp

# 2. Build Python App (official python:3.11-slim)
echo "--> Building k8s-lab/python-app:latest..."
$CONTAINER_CLI build -t k8s-lab/python-app:latest src/PythonApp

# 3. Build .NET App (official mcr.microsoft.com/dotnet/sdk:8.0)
echo "--> Building k8s-lab/dotnet-app:latest..."
$CONTAINER_CLI build -t k8s-lab/dotnet-app:latest src/CsharpApi

# 4. Load into Kind if kind cluster is available
if command -v kind >/dev/null 2>&1 && kind get clusters 2>/dev/null | grep -q "^${CLUSTER_NAME}$"; then
  echo "--> Loading images into Kind cluster '${CLUSTER_NAME}'..."
  kind load docker-image k8s-lab/java-app:latest --name "${CLUSTER_NAME}"
  kind load docker-image k8s-lab/python-app:latest --name "${CLUSTER_NAME}"
  kind load docker-image k8s-lab/dotnet-app:latest --name "${CLUSTER_NAME}"
  echo "Images loaded into Kind successfully!"
else
  echo "[INFO] Kind cluster '${CLUSTER_NAME}' not found. Images built locally in $CONTAINER_CLI."
fi

echo "=== All images built successfully! ==="
