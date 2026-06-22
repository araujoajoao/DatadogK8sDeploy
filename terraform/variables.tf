variable "datadog_api_key" {
  description = "Datadog API key. Can also be set via TF_VAR_datadog_api_key environment variable."
  type        = string
  sensitive   = true
}

variable "datadog_app_key" {
  description = "Datadog Application key. Can also be set via TF_VAR_datadog_app_key environment variable."
  type        = string
  sensitive   = true
}

variable "notification_email" {
  description = "Email address for Datadog monitor alert notifications."
  type        = string
  default     = "notify@example.com"
}

variable "env" {
  description = "Environment name used in resource names, tags, and metric queries."
  type        = string
  default     = "k8s-lab"

}

variable "api_url" {
  description = "Datadog API URL."
  type        = string
  default     = "https://api.datadoghq.com/"
}

variable "api_key" {
  description = "Datadog API key."
  type        = string
  sensitive   = true
}

variable "app_key" {
  description = "Datadog Application key."
  type        = string
  sensitive   = true
}
