resource "datadog_dashboard" "error_dashboard" {
  title       = "[${var.env}] Application Error Dashboard"
  description = "Identify errors across services using logs, metrics, and traces"
  layout_type = "ordered"

  widget {
    timeseries_definition {
      title       = "Error Rate by Service"
      show_legend = true

      request {
        q            = "sum:trace.http.request.errors{env:${var.env}} by {service}.as_rate()"
        display_type = "line"
        style {
          palette    = "warm"
          line_type  = "solid"
          line_width = "normal"
        }
      }

      yaxis {
        scale        = "linear"
        min          = "auto"
        max          = "auto"
        include_zero = true
        label        = "errors/s"
      }
    }
  }

  widget {
    toplist_definition {
      title = "Top Errors by Occurrence (Last 1h)"

      request {
        log_query {
          index = "*"

          search {
            query = "status:error env:${var.env}"
          }

          group_by {
            facet = "service"
            limit = 10

            sort {
              aggregation = "count"
              order       = "desc"
            }
          }

          compute {
            aggregation = "count"
          }
        }
      }
    }
  }

  widget {
    log_stream_definition {
      title   = "Recent Error Logs"
      query   = "status:error env:${var.env}"
      indexes = ["*"]
      columns = ["core_host", "core_service", "core_status", "core_message"]
      show_date_column    = true
      show_message_column = true
      message_display     = "expanded-md"

      sort {
        column = "time"
        order  = "desc"
      }
    }
  }

  widget {
    timeseries_definition {
      title = "HTTP 5xx Errors vs Total Requests"

      request {
        q            = "sum:trace.http.request.errors{env:${var.env}} by {service}.as_rate()"
        display_type = "bars"
        style {
          palette = "warm"
        }
      }

      request {
        q            = "sum:trace.http.request.hits{env:${var.env}} by {service}.as_rate()"
        display_type = "line"
        style {
          palette = "cool"
        }
      }
    }
  }

  widget {
    service_map_definition {
      title   = "Service Map"
      filters = ["env:${var.env}"]
    }
  }
}
