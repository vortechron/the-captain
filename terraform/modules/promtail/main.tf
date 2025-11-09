# Promtail Namespace (reuse observability namespace)
data "kubernetes_namespace" "observability" {
  metadata {
    name = var.namespace
  }
}

# Helm Release for Promtail
resource "helm_release" "promtail" {
  name       = "promtail"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "promtail"
  version    = var.chart_version
  namespace  = var.namespace
  create_namespace = false

  atomic          = false  # Non-critical: disable atomic for faster applies
  wait            = var.helm_wait_enabled
  wait_for_jobs   = var.helm_wait_for_jobs_enabled
  timeout         = 60  # Minimal timeout for Helm API calls
  reuse_values    = false
  force_update    = false
  cleanup_on_fail = true

  values = [
    yamlencode({
      # Removed timestamp annotation to avoid unnecessary diffs on every apply
      # Pods will restart automatically when Helm values actually change

      config = {
        clients = [
          {
            url = var.loki_url
          }
        ]

        scrape_configs = [
          {
            job_name = "kubernetes-pods"
            kubernetes_sd_configs = [
              {
                role = "pod"
              }
            ]

            pipeline_stages = [
              {
                json = {
                  expressions = {}
                }
              },
              {
                timestamp = {
                  format     = "RFC3339Nano"
                  source     = "timestamp"
                }
              },
              {
                timestamp = {
                  format     = "2006-01-02T15:04:05.999999Z07:00"
                  source     = "datetime"
                }
              },
              {
                labels = {
                  level      = "level"
                  level_name = "level_name"
                  channel     = "channel"
                  method      = "method"
                  route       = "route"
                  status      = "status"
                  user_id     = "user_id"
                  request_id  = "request_id"
                  trace_id    = "trace_id"
                }
              }
            ]

            relabel_configs = [
              {
                action        = "keep"
                regex         = true
                source_labels = ["__meta_kubernetes_pod_annotation_prometheus_io_scrape"]
              },
              {
                source_labels = ["__meta_kubernetes_namespace"]
                target_label  = "kubernetes_namespace"
              },
              {
                source_labels = ["__meta_kubernetes_pod_name"]
                target_label  = "kubernetes_pod_name"
              },
              {
                source_labels = ["__meta_kubernetes_pod_container_name"]
                target_label  = "kubernetes_container_name"
              },
              {
                source_labels = ["__meta_kubernetes_pod_label_app"]
                target_label  = "app"
              }
            ]
          },
          {
            job_name = "kubernetes-pods-static"
            kubernetes_sd_configs = [
              {
                role = "pod"
              }
            ]

            pipeline_stages = [
              {
                json = {
                  expressions = {}
                }
              }
            ]

            relabel_configs = [
              {
                action        = "drop"
                regex         = true
                source_labels = ["__meta_kubernetes_pod_annotation_prometheus_io_scrape"]
              },
              {
                source_labels = ["__meta_kubernetes_namespace"]
                target_label  = "kubernetes_namespace"
              },
              {
                source_labels = ["__meta_kubernetes_pod_name"]
                target_label  = "kubernetes_pod_name"
              },
              {
                source_labels = ["__meta_kubernetes_pod_container_name"]
                target_label  = "kubernetes_container_name"
              }
            ]
          }
        ]
      }

      resources = {
        requests = {
          cpu    = var.resources.requests.cpu
          memory = var.resources.requests.memory
        }
        limits = {
          cpu    = var.resources.limits.cpu
          memory = var.resources.limits.memory
        }
      }
    })
  ]

  depends_on = [data.kubernetes_namespace.observability]
}

