resource "datadog_monitor" "pod_memory_high" {
  name    = "[${var.env}] Pod Memory Usage Above 75%"
  type    = "metric alert"
  message = <<-EOT
    Pod {{pod_name.name}} in namespace {{kube_namespace.name}} is using more than 75% of its memory limit.

    Check the pod logs and resource usage.

    @${var.notification_email}
  EOT

  query = "max(last_5m):( max:kubernetes.memory.usage{env:${var.env}} by {pod_name,kube_namespace} / max:kubernetes.memory.limits{env:${var.env}} by {pod_name,kube_namespace} ) * 100 > 75"

  monitor_thresholds {
    warning  = 60
    critical = 75
  }

  notify_no_data    = false
  renotify_interval = 30

  tags = ["env:${var.env}", "team:observability", "project:appoena-lab"]
}

resource "datadog_monitor" "pod_crash_loop_backoff" {
  name    = "[${var.env}] Pod in CrashLoopBackOff"
  type    = "metric alert"
  message = <<-EOT
    Pod {{kube_pod.name}} in namespace {{kube_namespace.name}} is in CrashLoopBackOff state.

    Check pod events and logs:
    kubectl logs {{kube_pod.name}} -n {{kube_namespace.name}} --previous

    @${var.notification_email}
  EOT

  query = "max(last_10m):max:kubernetes_state.container.status_report.count.waiting{reason:crashloopbackoff,env:${var.env}} by {kube_namespace,kube_pod} >= 1"

  monitor_thresholds {
    critical = 1
  }

  notify_no_data    = false
  renotify_interval = 15

  tags = ["env:${var.env}", "team:observability", "project:appoena-lab"]
}
