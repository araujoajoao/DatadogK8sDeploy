#!/usr/bin/env bash
#
# Destroys Datadog monitors and dashboards created by deploy-datadog-resources.sh.
# Reads resource IDs from the state file written during deployment.
# If the state file is missing, falls back to searching by name.
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
        die "Required command '$1' is not installed. Please install it and retry."
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

    if [[ "$http_status" == "000" ]]; then
        die "curl failed to connect to ${API_BASE}${endpoint}. Check your network."
    fi

    if [[ "$http_status" == "200" || "$http_status" == "204" ]]; then
        log "  → deleted ${resource_type} ID ${resource_id}"
        return 0
    elif [[ "$http_status" == "404" ]]; then
        warn "  → ${resource_type} ID ${resource_id} not found (already deleted)"
        return 0
    else
        die "API DELETE failed for ${resource_type} ID ${resource_id} with HTTP status ${http_status}: ${body}"
    fi
}

# ── Prerequisite checks ───────────────────────────────────────────────────────

check_cmd curl
check_cmd jq

if [[ -z "$DATADOG_API_KEY" ]]; then
    die "DATADOG_API_KEY environment variable is not set. Set it and retry."
fi

if [[ -z "$DATADOG_APP_KEY" ]]; then
    die "DATADOG_APP_KEY environment variable is not set. Set it and retry."
fi

log "Datadog API key found: ${DATADOG_API_KEY:0:6}..."

# ── Load state file (or fall back to search-by-name) ──────────────────────────

if [[ ! -f "$STATE_FILE" ]]; then
    log "State file not found: ${STATE_FILE}"
    log "Falling back to search-by-name ..."

    # Search for monitors by name
    log "Searching for monitors matching [${ENV}] ..."
    local mem_response crash_response
    mem_response=$(curl -s -G -H "${HEADER_API_KEY}" -H "${HEADER_APP_KEY}" \
        "${API_BASE}/monitor" \
        --data-urlencode "name=[${ENV}] Pod Memory Usage Above 75%" 2>&1) || true

    local mem_ids crashloop_ids
    mem_ids=$(printf '%s' "$mem_response" \
        | jq -r --arg env "$ENV" '.[] | select(.name == "[" + $env + "] Pod Memory Usage Above 75%") | .id' 2>/dev/null || true)

    crash_response=$(curl -s -G -H "${HEADER_API_KEY}" -H "${HEADER_APP_KEY}" \
        "${API_BASE}/monitor" \
        --data-urlencode "name=[${ENV}] Pod in CrashLoopBackOff" 2>&1) || true
    crashloop_ids=$(printf '%s' "$crash_response" \
        | jq -r --arg env "$ENV" '.[] | select(.name == "[" + $env + "] Pod in CrashLoopBackOff") | .id' 2>/dev/null || true)

    local monitor_ids
    monitor_ids=$(printf '%s\n%s' "$mem_ids" "$crashloop_ids" | grep -v '^$')

    # Search for dashboard by title
    log "Searching for dashboards matching [${ENV}] Application Error Dashboard ..."
    local dash_response
    dash_response=$(curl -s -H "${HEADER_API_KEY}" -H "${HEADER_APP_KEY}" \
        "${API_BASE}/dashboard" 2>&1) || true
    local dashboard_id
    dashboard_id=$(printf '%s' "$dash_response" \
        | jq -r --arg env "$ENV" '.dashboards[] | select(.title == "[" + $env + "] Application Error Dashboard") | .id' 2>/dev/null || true)

    # No resources found
    if [[ -z "$monitor_ids" && -z "$dashboard_id" ]]; then
        echo
        echo "No resources found for ENV=${ENV} in Datadog. Nothing to delete."
        echo "============================================"
        exit 0
    fi

    MONITOR_IDS="$monitor_ids"
    DASHBOARD_ID="${dashboard_id:-}"

    echo
    echo "WARNING: State file ${STATE_FILE} not found."
    echo "Resources found via search for ENV=${ENV}:"
    echo
    echo "Monitors:"
    if [[ -n "$MONITOR_IDS" ]]; then
        echo "$MONITOR_IDS" | while read -r id; do
            [[ -n "$id" ]] && printf '  %-35s %s\n' "" "ID ${id}"
        done
    else
        echo "  (none found)"
    fi
    echo "Dashboard:"
    if [[ -n "$DASHBOARD_ID" ]]; then
        printf '  %-35s %s\n' "" "ID ${DASHBOARD_ID}"
    else
        echo "  (none found)"
    fi
    echo
    echo "============================================"
    echo
    read -rp "Proceed with deletion? [y/N] " confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        log "Aborted. No resources were deleted."
        exit 0
    fi
else
    if ! jq empty "$STATE_FILE" 2>/dev/null; then
        die "State file is not valid JSON: ${STATE_FILE}"
    fi

    MONITOR_IDS=$(jq -r '.monitor_ids[]' "$STATE_FILE")
    DASHBOARD_ID=$(jq -r '.dashboard_id' "$STATE_FILE")

    log "Loaded state file: ${STATE_FILE}"
    log "Monitors to delete: $(echo "$MONITOR_IDS" | wc -l | tr -d ' ')"
    log "Dashboard to delete: ${DASHBOARD_ID}"

    echo
    echo "============================================"
    echo "  Datadog Resources — Destruction Summary"
    echo "============================================"
    echo
    echo "This will DELETE the following resources:"
    echo
    echo "Monitors:"
    echo "$MONITOR_IDS" | while read -r id; do
        [[ -n "$id" ]] && printf '  %-35s %s\n' "" "ID ${id}"
    done
    printf '  %-35s %s\n' "" "dashboard ID ${DASHBOARD_ID}"
    echo
    echo "============================================"
    echo

    read -rp "Proceed with deletion? [y/N] " confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        log "Aborted. No resources were deleted."
        exit 0
    fi
fi

# ── Delete monitors ───────────────────────────────────────────────────────────

echo
log "Deleting monitors ..."

for monitor_id in $MONITOR_IDS; do
    [[ -z "$monitor_id" ]] && continue
    api_delete "/monitor/${monitor_id}" "monitor" "$monitor_id"
done

# ── Delete dashboard ──────────────────────────────────────────────────────────

log "Deleting dashboard ..."
api_delete "/dashboard/${DASHBOARD_ID}" "dashboard" "$DASHBOARD_ID"

# ── Remove state file ─────────────────────────────────────────────────────────

rm -f "$STATE_FILE"
log "State file removed: ${STATE_FILE}"

# ── Summary ───────────────────────────────────────────────────────────────────

echo
echo "============================================"
echo "  Datadog Resources — Destruction Complete"
echo "============================================"
echo
echo "All monitors and dashboards have been deleted."
echo "============================================"