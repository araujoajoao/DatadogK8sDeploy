terraform {
  required_providers {
    datadog = {
      source  = "DataDog/datadog"
      version = "~> 3.50"
    }
  }
}

provider "datadog" {
  api_url = var.api_url
  api_key = var.api_key
  app_key = var.app_key
}
