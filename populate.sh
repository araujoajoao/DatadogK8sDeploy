#!/usr/bin/env bash
# Sends traffic to all three apps to generate APM traces and logs in Datadog.
# Uses LoadBalancer IPs detected dynamically from the cluster.
set -euo pipefail

NAMESPACE="apps"
ROUNDS="${1:-3}"   # number of request rounds per endpoint (default 3)

# ── resolve LoadBalancer IPs ────────────────────────────────────────────────
JAVA_IP=$(kubectl get svc java-app   -n "$NAMESPACE" -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)
PY_IP=$(kubectl get svc python-app   -n "$NAMESPACE" -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)
DN_IP=$(kubectl get svc dotnet-app   -n "$NAMESPACE" -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)

if [[ -z "$JAVA_IP" || -z "$PY_IP" || -z "$DN_IP" ]]; then
  echo "ERROR: One or more LoadBalancer IPs are not assigned yet."
  echo "  Make sure 'sudo cloud-provider-kind' is running."
  kubectl get svc -n "$NAMESPACE"
  exit 1
fi

JAVA_URL="http://${JAVA_IP}:8080"
PY_URL="http://${PY_IP}:5000"
DN_URL="http://${DN_IP}:80"

echo "=== Datadog K8s Lab — Traffic Generator ==="
echo "  java-app   : $JAVA_URL"
echo "  python-app : $PY_URL"
echo "  dotnet-app : $DN_URL"
echo "  Rounds     : $ROUNDS"
echo ""

ok=0; fail=0

hit() {
  local label="$1"
  local url="$2"
  local status
  status=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 "$url" || echo "000")
  if [[ "$status" =~ ^2 ]]; then
    echo "  [OK $status] $label — $url"
    ((ok++)) || true
  else
    echo "  [!! $status] $label — $url"
    ((fail++)) || true
  fi
}

for i in $(seq 1 "$ROUNDS"); do
  echo "── Round $i/$ROUNDS ────────────────────────────────"

  # java-app: triggers full distributed trace chain
  # java → python (/api/dotnet) → dotnet (/weatherforecast)
  hit "java   GET /greeting    (full trace chain)" "${JAVA_URL}/greeting"

  # individual endpoints
  hit "python GET /             " "${PY_URL}/"
  hit "python GET /api/dotnet   (python → dotnet)" "${PY_URL}/api/dotnet"
  hit "dotnet GET /weatherforecast" "${DN_URL}/weatherforecast"
  echo ""
done

echo "=== Done — OK: $ok  Failed: $fail ==="
if [[ "$fail" -gt 0 ]]; then
  echo "    Check 'kubectl get pods -n apps' and pod logs for errors."
  exit 1
fi
