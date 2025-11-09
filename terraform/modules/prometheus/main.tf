# Prometheus Namespace (reuse observability namespace)
data "kubernetes_namespace" "observability" {
  metadata {
    name = var.namespace
  }
}

# Helm Release for Prometheus
resource "helm_release" "prometheus" {
  name       = "prometheus"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "prometheus"
  version    = var.chart_version != "" ? var.chart_version : null
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
      server = {
        persistentVolume = {
          enabled      = true
          storageClass = var.storage_class
          size         = var.storage_size
        }
        retention = var.retention_time
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
        # Prefer d4pool node for better resource distribution
        affinity = {
          nodeAffinity = {
            preferredDuringSchedulingIgnoredDuringExecution = [
              {
                weight = 100
                preference = {
                  matchExpressions = [
                    {
                      key      = "kubernetes.azure.com/agentpool"
                      operator = "In"
                      values   = ["d4pool"]
                    }
                  ]
                }
              }
            ]
          }
        }
      }

      nodeExporter = {
        enabled = var.enable_node_exporter
      }

      kubeStateMetrics = {
        enabled = var.enable_kube_state_metrics
      }

      alertmanager = {
        enabled = false  # Disable alertmanager for cost optimization
      }

      pushgateway = {
        enabled = false  # Disable pushgateway for cost optimization
      }
    })
  ]

  depends_on = [data.kubernetes_namespace.observability]
}

