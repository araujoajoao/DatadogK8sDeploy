#!/usr/bin/env bash
#
# Creates the Kubernetes secret 'datadog-secret' from values in .env.
# This is the single source of truth for Datadog credentials; the
# hard-coded YAML in kubernetes/datadog-secret.yaml is deprecated.
#
# Security: never source this script (run it via bash). Keys are read
# from .env and never exported to the parent shell or bash history.
#

set -euo pipefail

# Prevent this script's commands from entering interactive bash history
set +o history 2>/dev/null || true

# Guard against accidental sourcing
if [[ "${BASH_SOURCE[0]}" != "$0" ]]; then
    echo "[ERROR] Do not source this script. Run: bash $0" >&2
    return 1 2>/dev/null || exit 1
fi

# Resolve repo root (two levels up from scripts/)
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ENV_FILE="${REPO_ROOT}/.env"

if [[ ! -f "$ENV_FILE" ]]; then
    echo "[ERROR] $ENV_FILE not found. Copy .env.example and fill in your keys."
    exit 1
fi

# shellcheck source=/dev/null
source "$ENV_FILE"

DATADOG_API_KEY="${DATADOG_API_KEY:-}"
DATADOG_APP_KEY="${DATADOG_APP_KEY:-}"

if [[ -z "$DATADOG_API_KEY" || "$DATADOG_API_KEY" == "YOUR_API_KEY" ]]; then
    echo "[ERROR] DATADOG_API_KEY is not set in $ENV_FILE"
    exit 1
fi

if [[ -z "$DATADOG_APP_KEY" || "$DATADOG_APP_KEY" == "YOUR_APP_KEY" ]]; then
    echo "[ERROR] DATADOG_APP_KEY is not set in $ENV_FILE"
    exit 1
fi

echo "[INFO] Creating secret 'datadog-secret' in namespace 'default' …"

# Build a temporary env-file so keys never appear in 'ps' output
TMP_ENV=$(mktemp)
trap 'rm -f "$TMP_ENV"' EXIT
printf '%s\n' "api-key=$DATADOG_API_KEY" "app-key=$DATADOG_APP_KEY" > "$TMP_ENV"

# Create or replace the secret from the temporary file
kubectl create secret generic datadog-secret \
    --from-env-file="$TMP_ENV" \
    -n default \
    -o yaml --dry-run=client | kubectl apply -f - >/dev/null

echo "[INFO] Verifying secret contents …"

# Quick sanity check: decode and ensure they look like real keys
DECODED_API=$(kubectl get secret datadog-secret -n default -o jsonpath='{.data.api-key}' | base64 -d)
DECODED_APP=$(kubectl get secret datadog-secret -n default -o jsonpath='{.data.app-key}' | base64 -d)

if [[ "$DECODED_API" != "$DATADOG_API_KEY" ]]; then
    echo "[ERROR] API key in secret does not match .env"
    exit 1
fi

if [[ "$DECODED_APP" != "$DATADOG_APP_KEY" ]]; then
    echo "[ERROR] App key in secret does not match .env"
    exit 1
fi

echo "[INFO] Secret verified. API key: ${DATADOG_API_KEY:0:6}…  App key: ${DATADOG_APP_KEY:0:6}…"
echo "[INFO] Restarting Datadog Agent pods so they pick up the new secret …"

# Restart by deleting agent pods (DaemonSet will recreate them)
kubectl delete pods -n default -l app=datadog-agent --wait=false

# Also restart cluster-agent and operator so they re-read the secret
kubectl rollout restart deployment/datadog-cluster-agent -n default 2>/dev/null || true
kubectl rollout restart deployment/datadog-operator -n default 2>/dev/null || true

echo "[INFO] Done. Agent pods are restarting now."
echo "[INFO] Run 'kubectl get pods -n default -w' to watch progress."
