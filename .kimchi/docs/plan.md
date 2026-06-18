# Plan: Deploy Lab Without Terraform

## Goal
Replace Terraform-based provisioning of Datadog resources (monitors + dashboard) with a pure shell script using the Datadog REST API, so the entire lab deploys with only `kubectl`, `helm`, `kind`, and `curl`.

## Chunk 1: Create `scripts/deploy-datadog-resources.sh`

**File:** `scripts/deploy-datadog-resources.sh`

**Behaviour:**
- Reads `DATADOG_API_KEY`, `DATADOG_APP_KEY`, `NOTIFICATION_EMAIL` (default `araujoaojoao@gmail.com`), and `ENV` (default `mentoria`) from environment variables.
- Validates prerequisites: `curl` and `jq` are installed.
- Validates at least `DATADOG_API_KEY` and `DATADOG_APP_KEY` are present.
- Creates two Datadog monitors via `POST /api/v1/monitor`:
  1. `[${ENV}] Pod Memory Usage Above 75%` — metric alert
  2. `[${ENV}] Pod in CrashLoopBackOff` — metric alert
- Creates one Datadog dashboard via `POST /api/v1/dashboard`:
  - `[${ENV}] Application Error Dashboard` — ordered layout with 5 widgets:
    1. Timeseries — Error Rate by Service
    2. Toplist — Top Errors by Occurrence (Last 1h)
    3. Log Stream — Recent Error Logs
    4. Timeseries — HTTP 5xx Errors vs Total Requests
    5. Service Map — Service Map filtered by env
- After successful creation, writes resource IDs to `scripts/.datadog-resource-ids.json` for later teardown.
- Prints human-readable summary of created resources.
- Exits non-zero on any API error (http != 200/202 or `errors` in response).

**API translation notes:**
- Monitor `query` and `message` strings are taken directly from Terraform, with var interpolation replaced by shell variable expansion.
- Monitor `options` field wraps terraform `monitor_thresholds` as `thresholds`.
- Dashboard widgets use Datadog API v1 JSON format (widget objects with `definition` keys).
- `env`, `notification_email` interpolated into queries, messages, and filters.

**Acceptance criteria:**
1. Script runs to completion with valid keys and produces no error output.
2. The resulting JSON file `scripts/.datadog-resource-ids.json` contains valid `monitor_ids` (array of 2 ints) and `dashboard_id` (string).
3. Each created monitor's name and query match the Terraform originals.
4. Each dashboard widget type and title match the Terraform originals.
5. Script exits with code 1 and helpful message if API_KEY / APP_KEY missing.

## Chunk 2: Create `scripts/destroy-datadog-resources.sh`

**File:** `scripts/destroy-datadog-resources.sh`

**Behaviour:**
- Reads `DATADOG_API_KEY` and `DATADOG_APP_KEY` from environment.
- Reads resource IDs from `scripts/.datadog-resource-ids.json` (created by deploy script).
- Deletes each monitor via `DELETE /api/v1/monitor/{id}`.
- Deletes dashboard via `DELETE /api/v1/dashboard/{id}`.
- Removes the state file after successful teardown.
- Prints summary of deleted resources.
- Falls back to name-based search if state file is missing (search by monitor name / dashboard title and delete matching resources).

**Acceptance criteria:**
1. With state file present, deletes exactly the 2 monitors and 1 dashboard without errors.
2. Without state file, finds resources by name and deletes them.
3. Prints success/failure per resource.

## Chunk 3: Update `README.md`

**File:** `README.md`

**Changes:**
- In the Quick Start Deploy section, replace the Terraform step (step 9) with two alternatives:
  - **Option A — Terraform (legacy)** — keep existing terraform instructions.
  - **Option B — Shell script (no Terraform)** — new instructions using `scripts/deploy-datadog-resources.sh`.
- Add the shell script steps to the Repository Structure section.
- Ensure the Teardown section mentions both `terraform destroy` **and** `scripts/destroy-datadog-resources.sh`.

**Acceptance criteria:**
1. README clearly shows both deployment paths.
2. Shell script path is presented as the primary / recommended method.
3. No stale references to terraform being the only way to provision Datadog resources.

## Chunk 4: Update `appoena-lab-deploy-guide.md`

**File:** `appoena-lab-deploy-guide.md`

**Changes:**
- Insert the shell-script deployment step alongside or in place of Terraform.
- Ensure the guide still validates the full end-to-end flow.

**Acceptance criteria:**
1. Guide lists shell-script provisioning as a valid alternative or replacement for Terraform.
2. No contradictions between README and deploy guide.

## Verification Strategy
- Run shellcheck on both scripts.
- The scripts are not run against the live Datadog API (requires real credentials), but syntax and JSON validity should be verified.
