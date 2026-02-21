# MeiliSearch Namespace
resource "kubernetes_namespace" "meilisearch" {
  metadata {
    name = var.namespace
    labels = {
      name = var.namespace
    }
  }
}

# MeiliSearch Helm Release
resource "helm_release" "meilisearch" {
  name       = var.release_name
  repository = "https://meilisearch.github.io/meilisearch-kubernetes"
  chart      = "meilisearch"
  version    = var.chart_version != "" ? var.chart_version : null
  namespace  = kubernetes_namespace.meilisearch.metadata[0].name
  create_namespace = false

  atomic          = false
  wait            = var.helm_wait_enabled
  wait_for_jobs   = var.helm_wait_for_jobs_enabled
  timeout         = 60
  reuse_values    = false
  force_update    = false
  cleanup_on_fail = true

  values = [
    yamlencode({
      environment = {
        MEILI_ENV        = "development"
        MEILI_MASTER_KEY = var.master_key
      }

      persistence = {
        enabled      = true
        storageClass = var.storage_class
        size         = var.storage_size
        accessMode   = "ReadWriteOnce"
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
        port = 7700
      }

      ingress = {
        enabled = false
      }
    })
  ]
}
