# Percona Operator Helm Release
resource "helm_release" "pxc_operator" {
  name       = "pxc-operator"
  repository = "https://percona.github.io/percona-helm-charts/"
  chart      = "pxc-operator"
  version    = var.operator_chart_version != "" ? var.operator_chart_version : null
  namespace  = kubernetes_namespace.mysql.metadata[0].name

  atomic          = true # Critical: keep atomic for safety
  wait            = var.helm_wait_enabled
  wait_for_jobs   = var.helm_wait_for_jobs_enabled
  timeout         = 60 # Minimal timeout for Helm API calls
  reuse_values    = false
  force_update    = false
  cleanup_on_fail = true

  values = [
    yamlencode({
      resources = {
        limits = {
          cpu    = "200m"
          memory = "500Mi"
        }
        requests = {
          cpu    = "100m"
          memory = "200Mi"
        }
      }
      rbac = {
        useClusterWideAccess = false
      }
      operator = {
        watchNamespace = var.namespace
      }
      leaderElection = true
      logLevel       = "INFO"
    })
  ]
}

