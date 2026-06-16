#!/usr/bin/env bash
#
# Deploys two Datadog monitors and one dashboard using the Datadog REST API v1.
# All configuration is read from environment variables.
#

set -euo pipefail

# ── Auto-source .env if present ───────────────────────────────────────────────
ENV_FILE="$(dirname "$0")/../.env"
if [[ -f "$ENV_FILE" ]]; then
    # shellcheck source=/dev/null
    source "$ENV_FILE"
fi

# ── Defaults ──────────────────────────────────────────────────────────────────

NOTIFICATION_EMAIL="${NOTIFICATION_EMAIL:-araujoaojoao@gmail.com}"
ENV="${ENV:-mentoria}"

DATADOG_API_KEY="${DATADOG_API_KEY:-}"
DATADOG_APP_KEY="${DATADOG_APP_KEY:-}"

STATE_FILE="$(dirname "$0")/.datadog-resource-ids.json"
API_BASE="https://api.datadoghq.com/api/v1"
HEADER_API_KEY="DD-API-KEY: ${DATADOG_API_KEY}"
HEADER_APP_KEY="DD-APPLICATION-KEY: ${DATADOG_APP_KEY}"

# ── Helpers ───────────────────────────────────────────────────────────────────

usage() {
    cat <<EOF
Usage: $0

Required environment variables:
  DATADOG_API_KEY       Datadog API key
  DATADOG_APP_KEY       Datadog application key

Optional environment variables:
  NOTIFICATION_EMAIL    Email address for alert notifications
                        (default: araujoaojoao@gmail.com)
  ENV                   Environment name used as a tag and in resource names
                        (default: mentoria)
EOF
    exit 1
}

log()  { echo "[INFO] $*"; }
warn() { echo "[WARN] $*" >&2; }
die()  { echo "[ERROR] $*" >&2; exit 1; }

# Check a command is available
check_cmd() {
    if ! command -v "$1" &>/dev/null; then
        die "Required command '$1' is not installed. Please install it and retry."
    fi
}

# POST to the Datadog API and capture the response body.
# Arguments:
#   $1  – endpoint path (e.g. /monitor)
#   $2  – JSON payload file path
# Returns 0 and prints response body on success; exits 1 on error.
api_post() {
    local endpoint="$1"
    local payload_file="$2"

    local response
    local http_status

    response=$(curl -s -w "\n%{http_code}" \
        -H "${HEADER_API_KEY}" \
        -H "${HEADER_APP_KEY}" \
        -H "Content-Type: application/json" \
        -X POST \
        -d @"${payload_file}" \
        "${API_BASE}${endpoint}" 2>&1) || true

    http_status=$(printf '%s' "$response" | tail -1)
    local body
    body=$(printf '%s' "$response" | sed '$d')

    # Check for curl-level errors (non-2xx is handled separately below)
    if [[ "$http_status" == "000" ]]; then
        die "curl failed to connect to ${API_BASE}${endpoint}. Check your network."
    fi

    # Parse response — look for an "errors" array at the top level
    local errors
    errors=$(printf '%s' "$body" | jq -r 'if (.errors | length > 0) then .errors | join("; ") else empty end' 2>/dev/null || true)

    if [[ -n "$errors" ]]; then
        die "API error (${http_status}): ${errors}"
    fi

    if [[ ! "$http_status" =~ ^[23][0-9][0-9]$ ]]; then
        die "API request failed with HTTP status ${http_status}: ${body}"
    fi

    printf '%s' "$body"
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

log "Datadog API key found    : ${DATADOG_API_KEY:0:6}..."
log "Notification email       : ${NOTIFICATION_EMAIL}"
log "Environment               : ${ENV}"

# ── Monitor payload files ─────────────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TMPDIR="${TMPDIR:-/tmp}"
PAYLOAD_MEM_MONITOR="${TMPDIR}/dd-payload-monitor-memory-$$.json"
PAYLOAD_CRASHLOOP_MONITOR="${TMPDIR}/dd-payload-monitor-crashloop-$$.json"
PAYLOAD_DASHBOARD="${TMPDIR}/dd-payload-dashboard-$$.json"

cleanup() {
    rm -f "$PAYLOAD_MEM_MONITOR" "$PAYLOAD_CRASHLOOP_MONITOR" "$PAYLOAD_DASHBOARD"
}
trap cleanup EXIT

# ── Monitor 1: Pod Memory Usage Above 75% ─────────────────────────────────────
# Use unquoted EOF so bash expands ${ENV} and ${NOTIFICATION_EMAIL} directly

cat > "$PAYLOAD_MEM_MONITOR" << EOF
{
  "name": "[${ENV}] Pod Memory Usage Above 75%",
  "type": "metric alert",
  "query": "max(last_5m):( max:kubernetes.memory.usage{env:${ENV}} by {pod_name,kube_namespace} / max:kubernetes.memory.limits{env:${ENV}} by {pod_name,kube_namespace} ) * 100 > 75",
  "message": "Pod {{pod_name.name}} in namespace {{kube_namespace.name}} is using more than 75% of its memory limit.\n\nCheck the pod logs and resource usage.\n\n@${NOTIFICATION_EMAIL}",
  "tags": ["env:${ENV}", "team:observability", "project:appoena-lab"],
  "options": {
    "thresholds": {
      "critical": 75,
      "warning": 60
    },
    "notify_no_data": false,
    "renotify_interval": 30
  }
}
EOF

log "Creating monitor: Pod Memory Usage Above 75% ..."

MEM_RESPONSE=$(api_post "/monitor" "$PAYLOAD_MEM_MONITOR")
MEM_ID=$(printf '%s' "$MEM_RESPONSE" | jq -r '.id')
if [[ -z "$MEM_ID" || "$MEM_ID" == "null" ]]; then
    die "Failed to parse monitor ID from response: ${MEM_RESPONSE}"
fi
log "  → created with ID ${MEM_ID}"

# ── Monitor 2: Pod in CrashLoopBackOff ────────────────────────────────────────

cat > "$PAYLOAD_CRASHLOOP_MONITOR" << EOF
{
  "name": "[${ENV}] Pod in CrashLoopBackOff",
  "type": "metric alert",
  "query": "max(last_10m):max:kubernetes_state.container.status_report.count.waiting{reason:crashloopbackoff,env:${ENV}} by {kube_namespace,kube_pod} >= 1",
  "message": "Pod {{kube_pod.name}} in namespace {{kube_namespace.name}} is in CrashLoopBackOff state.\n\nCheck pod events and logs:\nkubectl logs {{kube_pod.name}} -n {{kube_namespace.name}} --previous\n\n@${NOTIFICATION_EMAIL}",
  "tags": ["env:${ENV}", "team:observability", "project:appoena-lab"],
  "options": {
    "thresholds": {
      "critical": 1
    },
    "notify_no_data": false,
    "renotify_interval": 15
  }
}
EOF

log "Creating monitor: Pod in CrashLoopBackOff ..."

CRASHLOOP_RESPONSE=$(api_post "/monitor" "$PAYLOAD_CRASHLOOP_MONITOR")
CRASHLOOP_ID=$(printf '%s' "$CRASHLOOP_RESPONSE" | jq -r '.id')
if [[ -z "$CRASHLOOP_ID" || "$CRASHLOOP_ID" == "null" ]]; then
    die "Failed to parse monitor ID from response: ${CRASHLOOP_RESPONSE}"
fi
log "  → created with ID ${CRASHLOOP_ID}"

# ── Dashboard: Application Error Dashboard ────────────────────────────────────
# Use unquoted EOF so bash expands ${ENV} directly into the JSON payload.
# No jq substitution needed — the JSON is already expanded.

cat > "$PAYLOAD_DASHBOARD" << EOF
{
  "title": "[${ENV}] Application Error Dashboard",
  "description": "Identify errors across services using logs, metrics, and traces",
  "layout_type": "ordered",
  "widgets": [
    {
      "definition": {
        "type": "timeseries",
        "title": "Error Rate by Service",
        "show_legend": true,
        "requests": [
          {
            "q": "sum:trace.http.request.errors{env:${ENV}} by {service}.as_rate()",
            "display_type": "line",
            "style": {
              "palette": "warm",
              "line_type": "solid",
              "line_width": "normal"
            }
          }
        ],
        "yaxis": {
          "scale": "linear",
          "min": "auto",
          "max": "auto",
          "include_zero": true,
          "label": "errors/s"
        }
      }
    },
    {
      "definition": {
        "type": "toplist",
        "title": "Top Errors by Occurrence (Last 1h)",
        "requests": [
          {
            "log_query": {
              "index": "*",
              "search": {
                "query": "status:error env:${ENV}"
              },
              "group_by": [
                {
                  "facet": "service",
                  "limit": 10,
                  "sort": {
                    "aggregation": "count",
                    "order": "desc"
                  }
                }
              ],
              "compute": {
                "aggregation": "count"
              }
            }
          }
        ]
      }
    },
    {
      "definition": {
        "type": "log_stream",
        "title": "Recent Error Logs",
        "query": "status:error env:${ENV}",
        "indexes": ["*"],
        "columns": ["core_host", "core_service", "core_status", "core_message"],
        "show_date_column": true,
        "show_message_column": true,
        "message_display": "expanded-md",
        "sort": {
          "column": "time",
          "order": "desc"
        }
      }
    },
    {
      "definition": {
        "type": "timeseries",
        "title": "HTTP 5xx Errors vs Total Requests",
        "requests": [
          {
            "q": "sum:trace.http.request.errors{env:${ENV}} by {service}.as_rate()",
            "display_type": "bars",
            "style": {
              "palette": "warm"
            }
          },
          {
            "q": "sum:trace.http.request.hits{env:${ENV}} by {service}.as_rate()",
            "display_type": "line",
            "style": {
              "palette": "cool"
            }
          }
        ]
      }
    },
    {
      "definition": {
        "type": "servicemap",
        "title": "Service Map",
        "service": "",
        "filters": ["env:${ENV}"]
      }
    }
  ]
}
EOF

log "Creating dashboard: Application Error Dashboard ..."

DASH_RESPONSE=$(api_post "/dashboard" "$PAYLOAD_DASHBOARD")
DASH_ID=$(printf '%s' "$DASH_RESPONSE" | jq -r '.id')
if [[ -z "$DASH_ID" || "$DASH_ID" == "null" ]]; then
    die "Failed to parse dashboard ID from response: ${DASH_RESPONSE}"
fi
log "  → created with ID ${DASH_ID}"

# ── Write resource IDs to state file ──────────────────────────────────────────

cat > "$STATE_FILE" << EOF
{
  "monitor_ids": [${MEM_ID}, ${CRASHLOOP_ID}],
  "dashboard_id": "${DASH_ID}"
}
EOF

log "Resource IDs written to: ${STATE_FILE}"

# ── Summary ───────────────────────────────────────────────────────────────────

echo
echo "============================================"
echo "  Datadog Resources — Deployment Summary"
echo "============================================"
echo
echo "Environment : ${ENV}"
echo "Notification: ${NOTIFICATION_EMAIL}"
echo
printf '  %-35s %s\n' "Pod Memory Usage Above 75%" "monitor ID ${MEM_ID}"
printf '  %-35s %s\n' "Pod in CrashLoopBackOff"     "monitor ID ${CRASHLOOP_ID}"
printf '  %-35s %s\n' "Application Error Dashboard" "dashboard ID ${DASH_ID}"
echo
echo "State file: ${STATE_FILE}"
echo "============================================"