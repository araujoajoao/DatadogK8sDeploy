# =============================================================================
# Datadog Resources — Terraform Configuration
# =============================================================================
#
# This Terraform configuration manages Datadog monitors and dashboards for
# the k8s-datadog lab environment.
#
# Usage:
#   1. Initialize Terraform:
#      terraform init
#
#   2. Preview changes:
#      terraform plan
#
#   3. Apply changes:
#      terraform apply
#
# Credentials:
#   After sourcing your .env file, export the Datadog credentials as
#   environment variables so Terraform can use them:
#      source ../.env
#      export TF_VAR_datadog_api_key="$DATADOG_API_KEY"
#      export TF_VAR_datadog_app_key="$DATADOG_APP_KEY"
#
#   Alternatively, create a terraform.tfvars file (see terraform.tfvars.example).
#
# Teardown:
#   To destroy all resources:
#      terraform destroy
#
# =============================================================================