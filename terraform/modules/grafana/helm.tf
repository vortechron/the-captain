# Helm Repository for Grafana
resource "helm_release" "grafana" {
  name       = "grafana"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "grafana"
  version    = var.chart_version
  namespace  = kubernetes_namespace.grafana.metadata[0].name
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
      adminUser     = var.admin_user
      adminPassword = var.admin_password != "" ? var.admin_password : null
      
      persistence = {
        enabled      = true
        storageClass = var.storage_class
        size         = var.storage_size
        accessModes  = ["ReadWriteOnce"]
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

      service = {
        type = "ClusterIP"
        port = 80
      }

      ingress = {
        enabled = false  # We'll create ingress separately for more control
      }
    })
  ]
}





