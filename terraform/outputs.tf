output "monitor_memory_id" {
  description = "ID of the Pod Memory Usage Above 98% monitor"
  value       = datadog_monitor.pod_memory_high.id
}

output "monitor_crashloop_id" {
  description = "ID of the Pod in CrashLoopBackOff monitor"
  value       = datadog_monitor.pod_crash_loop_backoff.id
}

output "dashboard_id" {
  description = "ID of the Application Error Dashboard"
  value       = datadog_dashboard.error_dashboard.id
}

output "dashboard_url" {
  description = "URL to access the Application Error Dashboard in Datadog"
  value       = "https://app.datadoghq.com/dashboard/${datadog_dashboard.error_dashboard.id}"
}