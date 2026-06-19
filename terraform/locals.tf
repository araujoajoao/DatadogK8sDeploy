locals {
  env                = var.env
  notification_email = var.notification_email
  project_tags       = ["env:${var.env}", "team:observability", "project:datadog-k8s-lab"]
}