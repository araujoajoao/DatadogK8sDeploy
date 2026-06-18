#!/usr/bin/env bash
#
# Destroys Datadog monitors and dashboards.
# Fixed version: removed invalid 'local' keywords from global scope.
#

set -euo pipefail

# ── Defaults ──────────────────────────────────────────────────────────────────

DATADOG_API_KEY="${DATADOG_API_KEY:-}"
DATADOG_APP_KEY="${DATADOG_APP_KEY:-}"
ENV="${ENV:-mentoria}"

STATE_FILE="$(dirname "$0")/.datadog-resource-ids.json"
API_BASE="https://api.datadoghq.com/api/v1"
HEADER_API_KEY="DD-API-KEY: ${DATADOG_API_KEY}"
HEADER_APP_KEY="DD-APPLICATION-KEY: ${DATADOG_APP_KEY}"

# ── Helpers ───────────────────────────────────────────────────────────────────

log()  { echo "[INFO] $*"; }
warn() { echo "[WARN] $*" >&2; }
die()  { echo "[ERROR] $*" >&2; exit 1; }

check_cmd() {
    if ! command -v "$1" &>/dev/null; then
        die "Required command '$1' is not installed."
    fi
}

api_delete() {
    local endpoint="$1"
    local resource_type="$2"
    local resource_id="$3"

    local response http_status body
    response=$(curl -s -w "\n%{http_code}" \
        -H "${HEADER_API_KEY}" \
        -H "${HEADER_APP_KEY}" \
        -X DELETE \
        "${API_BASE}${endpoint}" 2>&1) || true

    http_status=$(printf '%s' "$response" | tail -1)
    body=$(printf '%s' "$response" | sed '$d')

    if [[ "$http_status" == "200" || "$http_status" == "204" ]]; then
        log "  → deleted ${resource_type} ID ${resource_id}"
        return 0
    elif [[ "$http_status" == "404" ]]; then
        warn "  → ${resource_type} ID ${resource_id} not found"
        return 0
    else
        die "API DELETE failed: ${http_status}: ${body}"
    fi
}

# ── Prerequisite checks ───────────────────────────────────────────────────────

check_cmd curl
check_cmd jq

if [[ -z "$DATADOG_API_KEY" || -z "$DATADOG_APP_KEY" ]]; then
    die "DATADOG_API_KEY and DATADOG_APP_KEY must be set."
fi

# ── Load state or search ──────────────────────────────────────────────────────

if [[ ! -f "$STATE_FILE" ]]; then
    log "State file not found. Searching for monitors matching [${ENV}] ..."
    
    # Removed 'local' keywords below as they were causing syntax errors
    mem_response=$(curl -s -G -H "${HEADER_API_KEY}" -H "${HEADER_APP_KEY}" \
        "${API_BASE}/monitor" --data-urlencode "name=[${ENV}] Pod Memory Usage Above 75%" 2>&1) || true

    mem_ids=$(printf '%s' "$mem_response" | jq -r --arg env "$ENV" '.[] | select(.name == "[" + $env + "] Pod Memory Usage Above 75%") | .id' 2>/dev/null || true)

    crash_response=$(curl -s -G -H "${HEADER_API_KEY}" -H "${HEADER_APP_KEY}" \
        "${API_BASE}/monitor" --data-urlencode "name=[${ENV}] Pod in CrashLoopBackOff" 2>&1) || true
    crashloop_ids=$(printf '%s' "$crash_response" | jq -r --arg env "$ENV" '.[] | select(.name == "[" + $env + "] Pod in CrashLoopBackOff") | .id' 2>/dev/null || true)

    monitor_ids=$(printf '%s\n%s' "$mem_ids" "$crashloop_ids" | grep -v '^$')

    dash_response=$(curl -s -H "${HEADER_API_KEY}" -H "${HEADER_APP_KEY}" "${API_BASE}/dashboard" 2>&1) || true
    dashboard_id=$(printf '%s' "$dash_response" | jq -r --arg env "$ENV" '.dashboards[] | select(.title == "[" + $env + "] Application Error Dashboard") | .id' 2>/dev/null || true)

    MONITOR_IDS="$monitor_ids"
    DASHBOARD_ID="${dashboard_id:-}"
else
    MONITOR_IDS=$(jq -r '.monitor_ids[]' "$STATE_FILE")
    DASHBOARD_ID=$(jq -r '.dashboard_id' "$STATE_FILE")
fi

# ── Execution ────────────────────────────────────────────────────────────────

if [[ -z "$MONITOR_IDS" && -z "$DASHBOARD_ID" ]]; then
    log "No resources found to delete."
    exit 0
fi

echo "Proceeding to delete found resources..."
for monitor_id in $MONITOR_IDS; do
    api_delete "/monitor/${monitor_id}" "monitor" "$monitor_id"
done

if [[ -n "$DASHBOARD_ID" ]]; then
    api_delete "/dashboard/${DASHBOARD_ID}" "dashboard" "$DASHBOARD_ID"
fi

rm -f "$STATE_FILE"
log "Destruction complete."
