resource "datadog_dashboard" "error_dashboard" {
  title       = "[${local.env}] Application Error Dashboard"
  description = "Identify errors across services using logs, metrics, and traces"
  layout_type = "ordered"

  widget {
    timeseries_definition {
      title       = "Error Rate by Service"
      show_legend = true

      request {
        q            = "sum:trace.http.request.errors{env:${local.env}} by {service}.as_rate()"
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

          search_query = "status:error env:${local.env}"

          group_by {
            facet = "service"
            limit = 10

            sort_query {
              aggregation = "count"
              order       = "desc"
            }
          }

          compute_query {
            aggregation = "count"
          }
        }
      }
    }
  }

  widget {
    log_stream_definition {
      title               = "Recent Error Logs"
      query               = "status:error env:${local.env}"
      indexes             = ["*"]
      columns             = ["core_host", "core_service", "core_status", "core_message"]
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
        q            = "sum:trace.http.request.errors{env:${local.env}} by {service}.as_rate()"
        display_type = "bars"
        style {
          palette = "warm"
        }
      }

      request {
        q            = "sum:trace.http.request.hits{env:${local.env}} by {service}.as_rate()"
        display_type = "line"
        style {
          palette = "cool"
        }
      }
    }
  }

  widget {
    servicemap_definition {
      title   = "Service Map"
      service = ""
      filters = ["env:${local.env}"]
    }
  }
}