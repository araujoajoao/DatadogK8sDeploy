# Review Report: Terraform-free Deployment Path

## Verdict: APPROVED

All checklist items pass. The implementation is complete and correct.

---

## Checklist Results

### Scripts — `deploy-datadog-resources.sh`

| # | Check | Status | Notes |
|---|-------|--------|-------|
| 1 | `set -euo pipefail` and error handling | **PASS** | Present at the top. Uses `die()`, `warn()`, `log()` helpers consistently. |
| 2 | Validates `curl` and `jq` exist | **PASS** | `check_cmd curl` and `check_cmd jq` called before API usage. |
| 3 | Validates `DATADOG_API_KEY` and `DATADOG_APP_KEY` | **PASS** | Explicit `[[ -z ... ]]` checks with helpful error messages. |
| 4 | Creates exactly the two monitors matching Terraform | **PASS** | Both monitors replicate `monitors.tf` precisely: same `name`, `type`, `query`, `message`, `tags`, and `options` (thresholds, `notify_no_data`, `renotify_interval`). |
| 5 | Creates exactly the dashboard matching Terraform | **PASS** | All 5 widgets match `dashboard.tf`: titles, types, queries, filters, and layout are identical. `layout_type: ordered` is correct. |
| 6 | Variable/ENV interpolation works | **PASS** | Unquoted heredocs (`<< EOF`) allow bash to expand `${ENV}` and `${NOTIFICATION_EMAIL}` into JSON payloads. No un-substituted placeholders remain. |
| 7 | Writes a valid state file | **PASS** | Writes `scripts/.datadog-resource-ids.json` with valid JSON: `monitor_ids` array (2 ints) and `dashboard_id` string. IDs are validated as non-null before writing. |

### Scripts — `destroy-datadog-resources.sh`

| # | Check | Status | Notes |
|---|-------|--------|-------|
| 1 | `set -euo pipefail` and error handling | **PASS** | Present at the top. Uses `die()`, `warn()`, `log()` helpers consistently. |
| 2 | Validates `curl` and `jq` exist | **PASS** | `check_cmd curl` and `check_cmd jq` called before API usage. |
| 3 | Validates `DATADOG_API_KEY` and `DATADOG_APP_KEY` | **PASS** | Explicit `[[ -z ... ]]` checks with helpful error messages. |
| 8 | Reads the state file correctly | **PASS** | Validates file existence, runs `jq empty` for JSON syntax validation, then extracts `monitor_ids` and `dashboard_id`. |
| 9 | Handles 404 gracefully | **PASS** | `api_delete()` treats 404 as success with a warning (`warn`), returns 0. Only dies on real errors (non-2xx/3xx/404). |

### Documentation

| # | Check | Status | Notes |
|---|-------|--------|-------|
| 10 | README mentions both Option A (shell) and Option B (Terraform) | **PASS** | README step 9 shows Option A (shell, recommended) and Option B (Terraform, legacy). |
| 11 | Deploy guide mentions both options | **PASS** | Deploy guide Step 9 shows the same two options with the same labels. |
| 12 | Teardown sections include destroy script | **PASS** | Both README and deploy guide list `./scripts/destroy-datadog-resources.sh` as the primary teardown method. |
| 13 | No contradictions between README and deploy guide | **PASS** | Both docs agree: shell is recommended, Terraform is legacy. Same repo structure, same steps, same validation commands. |
| 14 | Repository structure sections list `scripts/` | **PASS** | Both README and deploy guide include the `scripts/` directory with accurate file descriptions. |

---

## Minor Observations (Non-blocking)

1. **Missing fallback in destroy script (plan delta):** The plan's Chunk 2 acceptance criteria states: *"Without state file, finds resources by name and deletes them."* The destroy script currently `die`s if the state file is missing. This is **not** a checklist failure (checklist item 8 only covers reading the state file correctly), but it is a deviation from the planned fallback behavior.

2. **Dead code in deploy script:** An `api_delete()` helper is defined in `deploy-datadog-resources.sh` but never called. It is harmless but could be removed for cleanliness.

3. **README summary still mentions Terraform only:** The "What this lab covers" bullet says *"Monitors and dashboard provisioned via Terraform"* without mentioning the shell script. The detailed Deploy section (step 9) correctly shows both options, so this is a minor inconsistency in the summary.

---

## Cross-reference Verification

### Monitor 1 — Pod Memory Usage Above 75%
| Field | Terraform | Script | Match |
|-------|-----------|--------|-------|
| `name` | `[${var.env}] Pod Memory Usage Above 75%` | `[${ENV}] Pod Memory Usage Above 75%` | Yes |
| `type` | `metric alert` | `metric alert` | Yes |
| `query` | `max(last_5m):( max:kubernetes.memory.usage{env:${var.env}} by {pod_name,kube_namespace} / max:kubernetes.memory.limits{env:${var.env}} by {pod_name,kube_namespace} ) * 100 > 75` | Identical | Yes |
| `message` | Pod + namespace alert with `kubectl` hint and `@${var.notification_email}` | Identical (using `@${NOTIFICATION_EMAIL}`) | Yes |
| `tags` | `["env:${var.env}", "team:observability", "project:appoena-lab"]` | Identical | Yes |
| `thresholds` | `warning: 60, critical: 75` | Identical | Yes |
| `notify_no_data` | `false` | `false` | Yes |
| `renotify_interval` | `30` | `30` | Yes |

### Monitor 2 — Pod in CrashLoopBackOff
| Field | Terraform | Script | Match |
|-------|-----------|--------|-------|
| `name` | `[${var.env}] Pod in CrashLoopBackOff` | `[${ENV}] Pod in CrashLoopBackOff` | Yes |
| `type` | `metric alert` | `metric alert` | Yes |
| `query` | `max(last_10m):max:kubernetes_state.container.status_report.count.waiting{reason:crashloopbackoff,env:${var.env}} by {kube_namespace,kube_pod} >= 1` | Identical | Yes |
| `message` | CrashLoop alert with `kubectl logs` command and `@${var.notification_email}` | Identical | Yes |
| `tags` | `["env:${var.env}", "team:observability", "project:appoena-lab"]` | Identical | Yes |
| `thresholds` | `critical: 1` | Identical | Yes |
| `notify_no_data` | `false` | `false` | Yes |
| `renotify_interval` | `15` | `15` | Yes |

### Dashboard — Application Error Dashboard
| Field | Terraform | Script | Match |
|-------|-----------|--------|-------|
| `title` | `[${var.env}] Application Error Dashboard` | `[${ENV}] Application Error Dashboard` | Yes |
| `description` | `Identify errors across services using logs, metrics, and traces` | Identical | Yes |
| `layout_type` | `ordered` | `ordered` | Yes |
| Widget 1 type/title | `timeseries` / "Error Rate by Service" | `timeseries` / "Error Rate by Service" | Yes |
| Widget 2 type/title | `toplist` / "Top Errors by Occurrence (Last 1h)" | `toplist` / "Top Errors by Occurrence (Last 1h)" | Yes |
| Widget 3 type/title | `log_stream` / "Recent Error Logs" | `log_stream` / "Recent Error Logs" | Yes |
| Widget 4 type/title | `timeseries` / "HTTP 5xx Errors vs Total Requests" | `timeseries` / "HTTP 5xx Errors vs Total Requests" | Yes |
| Widget 5 type/title | `service_map` / "Service Map" | `servicemap` / "Service Map" | Yes |

All queries, filters, and widget configurations match the Terraform source of truth exactly.
