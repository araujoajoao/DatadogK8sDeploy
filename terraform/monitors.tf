resource "datadog_monitor" "pod_memory_high" {
  name    = "[${local.env}] Pod Memory Usage Above 98%"
  type    = "metric alert"
  message = <<-EOT
    Pod {{pod_name.name}} in namespace {{kube_namespace.name}} is using more than 98% of its memory limit.

    Check the pod logs and resource usage.

    @${local.notification_email}
  EOT

  query = "max(last_5m):( max:kubernetes.memory.usage{env:${local.env}} by {pod_name,kube_namespace} / max:kubernetes.memory.limits{env:${local.env}} by {pod_name,kube_namespace} ) * 100 > 98"

  monitor_thresholds {
    warning  = 95
    critical = 98
  }

  notify_no_data    = false
  renotify_interval = 30

  tags = local.project_tags
}

resource "datadog_monitor" "pod_crash_loop_backoff" {
  name    = "[${local.env}] Pod in CrashLoopBackOff"
  type    = "metric alert"
  message = <<-EOT
    Pod {{kube_pod.name}} in namespace {{kube_namespace.name}} is in CrashLoopBackOff state.

    Check pod events and logs:
    kubectl logs {{kube_pod.name}} -n {{kube_namespace.name}} --previous

    @${local.notification_email}
  EOT

  query = "max(last_10m):max:kubernetes_state.container.status_report.count.waiting{reason:crashloopbackoff,env:${local.env}} by {kube_namespace,kube_pod} >= 1"

  monitor_thresholds {
    critical = 1
  }

  notify_no_data    = false
  renotify_interval = 15

  tags = local.project_tags
}