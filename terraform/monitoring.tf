# Terraform configuration for Cloud Monitoring: uptime check, alert policies and dashboard.
# The VM and Apache metrics come from the Ops Agent, installed in the image (packer/scripts/install.sh).

# ==========================================
# NOTIFICATION CHANNEL
# ==========================================

# Every alert goes to the operator by email: the same account that has IAP access, passed by the
# pipeline (_IAP_USER_EMAIL), never written in the repository.
resource "google_monitoring_notification_channel" "email" {
  depends_on   = [google_project_service.gcp_services]
  display_name = local.alert_channel_name
  type         = "email"
  labels = {
    email_address = var.iap_user_email
  }
}

# ==========================================
# UPTIME CHECK
# ==========================================

# HTTPS only. Uptime checks follow redirects, so a check on http:// would measure the final HTTPS
# page, not the 301; the redirect is checked by the smoke tests (tests/smoke/edge-security.sh).
#
# The home page, not /health.php: the home page needs the database, so the check covers WordPress
# and Cloud SQL together. /health.php stays healthy with the database down, on purpose (see the image).
#
# The content match avoids a false pass before WordPress is installed: / redirects to the installer,
# the installer to the IAP sign-in, and the check would follow the chain to a 200 from Google.
# "https://api.w.org/" is the REST API link WordPress prints in the <head> of every public page,
# whatever the theme. Neither the IAP sign-in nor install.php, which does not load the site's <head>,
# contains it (checked with curl on the deployed site, devlog-2026-11-09-verification.md, D5).
resource "google_monitoring_uptime_check_config" "https" {
  depends_on   = [google_project_service.gcp_services]
  display_name = local.uptime_check_name
  timeout      = "10s"
  period       = "60s"

  # At least three regions are required. An alert needs two of them failing (see below).
  selected_regions = ["EUROPE", "USA_VIRGINIA", "ASIA_PACIFIC"]

  http_check {
    path           = "/"
    port           = 443
    use_ssl        = true
    validate_ssl   = true
    request_method = "GET"

    accepted_response_status_codes {
      status_class = "STATUS_CLASS_2XX"
    }
  }

  content_matchers {
    content = "https://api.w.org/"
    matcher = "CONTAINS_STRING"
  }

  monitored_resource {
    type = "uptime_url"
    labels = {
      project_id = var.project_id
      host       = local.domain_names[0]
    }
  }
}

# ==========================================
# ALERT POLICIES
# ==========================================

# The site is down from at least two regions for two minutes. One failing region alone is usually
# a problem of that checker, not of the site.
resource "google_monitoring_alert_policy" "uptime" {
  display_name          = local.alert_uptime_name
  combiner              = "OR"
  notification_channels = [google_monitoring_notification_channel.email.id]

  conditions {
    display_name = "HTTPS uptime check failing in 2 or more regions"
    condition_threshold {
      filter          = "metric.type=\"monitoring.googleapis.com/uptime_check/check_passed\" AND metric.label.check_id=\"${google_monitoring_uptime_check_config.https.uptime_check_id}\" AND resource.type=\"uptime_url\""
      comparison      = "COMPARISON_GT"
      threshold_value = 1
      duration        = "120s"

      aggregations {
        alignment_period     = "60s"
        per_series_aligner   = "ALIGN_NEXT_OLDER"
        cross_series_reducer = "REDUCE_COUNT_FALSE"
        group_by_fields      = ["resource.label.host"]
      }
    }
  }

  documentation {
    content = "https://${local.domain_names[0]}/ is failing its uptime check. The home page needs the database: check the load balancer backends, the instances and Cloud SQL (dashboard ${local.monitoring_dashboard_name})."
  }
}

# The certificate expires in less than 15 days. Google renews the managed certificate by itself, but
# the renewal fails silently if the domain stops pointing to the load balancer.
resource "google_monitoring_alert_policy" "ssl_expiry" {
  display_name          = local.alert_ssl_expiry_name
  combiner              = "OR"
  notification_channels = [google_monitoring_notification_channel.email.id]

  conditions {
    display_name = "TLS certificate expires in less than 15 days"
    condition_threshold {
      filter          = "metric.type=\"monitoring.googleapis.com/uptime_check/time_until_ssl_cert_expires\" AND metric.label.check_id=\"${google_monitoring_uptime_check_config.https.uptime_check_id}\" AND resource.type=\"uptime_url\""
      comparison      = "COMPARISON_LT"
      threshold_value = 15
      duration        = "600s"

      aggregations {
        alignment_period     = "1200s"
        per_series_aligner   = "ALIGN_NEXT_OLDER"
        cross_series_reducer = "REDUCE_MEAN"
        group_by_fields      = ["resource.label.host"]
      }
    }
  }

  documentation {
    content = "The certificate of https://${local.domain_names[0]}/ expires in less than 15 days. Check that every domain still resolves to the load balancer IP and the status of the managed certificate."
  }
}

# The daily export could not be started: the scheduler job failed, or the function answered 5xx.
# The function only starts the export (an asynchronous Cloud SQL operation): an export that starts
# and then fails inside Cloud SQL is not caught here.
resource "google_monitoring_alert_policy" "export_failure" {
  display_name          = local.alert_export_failure_name
  combiner              = "OR"
  notification_channels = [google_monitoring_notification_channel.email.id]

  conditions {
    display_name = "Daily export job or function failed"
    condition_matched_log {
      filter = <<-EOT
        (resource.type="cloud_scheduler_job" AND resource.labels.job_id="${local.scheduler_export_name}" AND severity>=ERROR)
        OR
        (resource.type="cloud_run_revision" AND resource.labels.service_name="${local.db_backup_function_name}" AND log_id("run.googleapis.com/requests") AND httpRequest.status>=500)
      EOT
    }
  }

  # Required for log-based alerts: at most one notification per hour.
  alert_strategy {
    notification_rate_limit {
      period = "3600s"
    }
    auto_close = "86400s"
  }

  documentation {
    content = "The daily export of ${local.db_instance_name} did not start. Read the logs of the scheduler job ${local.scheduler_export_name} and of the function ${local.db_backup_function_name}, and run a manual export (README, Trigger a manual backup)."
  }
}

# Cloud SQL CPU or memory sustained above 80%: the signal to size the tier up (to-do T36).
resource "google_monitoring_alert_policy" "db_cpu" {
  display_name          = local.alert_db_cpu_name
  combiner              = "OR"
  notification_channels = [google_monitoring_notification_channel.email.id]

  conditions {
    display_name = "Cloud SQL CPU above 80% for 10 minutes"
    condition_threshold {
      filter          = "metric.type=\"cloudsql.googleapis.com/database/cpu/utilization\" AND resource.type=\"cloudsql_database\" AND resource.label.database_id=\"${var.project_id}:${local.db_instance_name}\""
      comparison      = "COMPARISON_GT"
      threshold_value = 0.8
      duration        = "600s"

      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_MEAN"
      }
    }
  }

  documentation {
    content = "${local.db_instance_name} has used more than 80% of its CPU for 10 minutes. Check Query Insights or the slow queries, then consider a larger tier (instance_tier)."
  }
}

resource "google_monitoring_alert_policy" "db_memory" {
  display_name          = local.alert_db_memory_name
  combiner              = "OR"
  notification_channels = [google_monitoring_notification_channel.email.id]

  conditions {
    display_name = "Cloud SQL memory above 80% for 10 minutes"
    condition_threshold {
      filter          = "metric.type=\"cloudsql.googleapis.com/database/memory/utilization\" AND resource.type=\"cloudsql_database\" AND resource.label.database_id=\"${var.project_id}:${local.db_instance_name}\""
      comparison      = "COMPARISON_GT"
      threshold_value = 0.8
      duration        = "600s"

      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_MEAN"
      }
    }
  }

  documentation {
    content = "${local.db_instance_name} has used more than 80% of its memory for 10 minutes. Consider a larger tier (instance_tier)."
  }
}

# ==========================================
# DASHBOARD
# ==========================================

# One dashboard for the whole site: Apache (Ops Agent), the instances, the load balancer and Cloud SQL.
locals {
  # One line chart: a title and a list of [filter, aligner, reducer, group by] series.
  dashboard_tiles = [
    { title = "Apache requests/s", series = [["metric.type=\"workload.googleapis.com/apache.requests\" resource.type=\"gce_instance\"", "ALIGN_RATE", "REDUCE_SUM", ["resource.label.instance_id"]]] },
    { title = "Apache workers by state", series = [["metric.type=\"workload.googleapis.com/apache.workers\" resource.type=\"gce_instance\"", "ALIGN_MEAN", "REDUCE_SUM", ["metric.label.state"]]] },
    { title = "Apache current connections", series = [["metric.type=\"workload.googleapis.com/apache.current_connections\" resource.type=\"gce_instance\"", "ALIGN_MEAN", "REDUCE_SUM", ["resource.label.instance_id"]]] },
    { title = "Apache traffic (bytes/s)", series = [["metric.type=\"workload.googleapis.com/apache.traffic\" resource.type=\"gce_instance\"", "ALIGN_RATE", "REDUCE_SUM", ["resource.label.instance_id"]]] },
    { title = "Instance CPU utilization", series = [["metric.type=\"compute.googleapis.com/instance/cpu/utilization\" resource.type=\"gce_instance\"", "ALIGN_MEAN", "REDUCE_MEAN", ["resource.label.instance_id"]]] },
    { title = "Instance memory used (%)", series = [["metric.type=\"agent.googleapis.com/memory/percent_used\" resource.type=\"gce_instance\" metric.label.state=\"used\"", "ALIGN_MEAN", "REDUCE_MEAN", ["resource.label.instance_id"]]] },
    { title = "Load balancer requests by response class", series = [["metric.type=\"loadbalancing.googleapis.com/https/request_count\" resource.type=\"https_lb_rule\"", "ALIGN_RATE", "REDUCE_SUM", ["metric.label.response_code_class"]]] },
    { title = "Load balancer latency, 95th percentile (ms)", series = [["metric.type=\"loadbalancing.googleapis.com/https/total_latencies\" resource.type=\"https_lb_rule\"", "ALIGN_DELTA", "REDUCE_PERCENTILE_95", []]] },
    { title = "Cloud SQL CPU utilization", series = [["metric.type=\"cloudsql.googleapis.com/database/cpu/utilization\" resource.type=\"cloudsql_database\"", "ALIGN_MEAN", "REDUCE_MEAN", []]] },
    { title = "Cloud SQL memory utilization", series = [["metric.type=\"cloudsql.googleapis.com/database/memory/utilization\" resource.type=\"cloudsql_database\"", "ALIGN_MEAN", "REDUCE_MEAN", []]] },
    { title = "Cloud SQL connections", series = [["metric.type=\"cloudsql.googleapis.com/database/network/connections\" resource.type=\"cloudsql_database\"", "ALIGN_MEAN", "REDUCE_SUM", []]] },
    { title = "Cloud SQL disk utilization", series = [["metric.type=\"cloudsql.googleapis.com/database/disk/utilization\" resource.type=\"cloudsql_database\"", "ALIGN_MEAN", "REDUCE_MEAN", []]] },
  ]
}

resource "google_monitoring_dashboard" "main" {
  depends_on = [google_project_service.gcp_services]

  # Two charts per row on a 48-column grid.
  dashboard_json = jsonencode({
    displayName = local.monitoring_dashboard_name
    mosaicLayout = {
      columns = 48
      tiles = [for i, tile in local.dashboard_tiles : {
        xPos   = (i % 2) * 24
        yPos   = floor(i / 2) * 16
        width  = 24
        height = 16
        widget = {
          title = tile.title
          xyChart = {
            dataSets = [for s in tile.series : {
              plotType = "LINE"
              timeSeriesQuery = {
                timeSeriesFilter = {
                  filter = s[0]
                  aggregation = {
                    alignmentPeriod    = "60s"
                    perSeriesAligner   = s[1]
                    crossSeriesReducer = s[2]
                    groupByFields      = s[3]
                  }
                }
              }
            }]
          }
        }
      }]
    }
  })
}
