#!/usr/bin/env bash
# Sends traffic to all three apps to generate APM traces and logs in Datadog.
# Uses LoadBalancer IPs detected dynamically from the cluster.
set -euo pipefail

NAMESPACE="apps"
ROUNDS="${1:-3}"   # number of request rounds per endpoint (default 3)

# ── resolve endpoints (LoadBalancer IP or port-forward fallback) ─────────────
PF_PIDS=()
cleanup() {
  if [ ${#PF_PIDS[@]} -gt 0 ]; then
    echo "Stopping port-forward processes..."
    for pid in "${PF_PIDS[@]}"; do
      kill "$pid" 2>/dev/null || true
    done
  fi
}
trap cleanup EXIT INT TERM

JAVA_IP=$(kubectl get svc java-app   -n "$NAMESPACE" -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || true)
PY_IP=$(kubectl get svc python-app   -n "$NAMESPACE" -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || true)
DN_IP=$(kubectl get svc dotnet-app   -n "$NAMESPACE" -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || true)

if [[ -n "$JAVA_IP" && -n "$PY_IP" && -n "$DN_IP" ]]; then
  echo "Using LoadBalancer IPs:"
  JAVA_URL="http://${JAVA_IP}:8080"
  PY_URL="http://${PY_IP}:5000"
  DN_URL="http://${DN_IP}:80"
else
  echo "LoadBalancer IPs not detected. Using local port-forward fallback..."
  kubectl port-forward svc/java-app -n "$NAMESPACE" 18080:8080 >/dev/null 2>&1 &
  PF_PIDS+=($!)
  kubectl port-forward svc/python-app -n "$NAMESPACE" 15000:5000 >/dev/null 2>&1 &
  PF_PIDS+=($!)
  kubectl port-forward svc/dotnet-app -n "$NAMESPACE" 18081:80 >/dev/null 2>&1 &
  PF_PIDS+=($!)

  sleep 2
  JAVA_URL="http://127.0.0.1:18080"
  PY_URL="http://127.0.0.1:15000"
  DN_URL="http://127.0.0.1:18081"
fi

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
  # dotnet endpoint (hits official aspnetapp or custom webapi)
  hit "dotnet GET /             " "${DN_URL}/"
  echo ""
done

echo "=== Done — OK: $ok  Failed: $fail ==="
if [[ "$fail" -gt 0 ]]; then
  echo "    Check 'kubectl get pods -n apps' and pod logs for errors."
  exit 1
fi
