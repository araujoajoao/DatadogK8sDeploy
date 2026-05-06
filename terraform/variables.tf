variable "datadog_api_key" {
  type      = string
  sensitive = true
}

variable "datadog_app_key" {
  type      = string
  sensitive = true
}

variable "notification_email" {
  type    = string
  default = "araujoaojoao@gmail.com"
}

variable "env" {
  type    = string
  default = "mentoria"
}
