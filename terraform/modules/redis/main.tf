# Redis Namespace
# Only create namespace if it's not "default" (which already exists)
resource "kubernetes_namespace" "redis" {
  count = var.namespace != "default" ? 1 : 0
  
  metadata {
    name = var.namespace
    labels = {
      name = var.namespace
    }
  }
}

# Data source for default namespace (if using default)
data "kubernetes_namespace" "redis" {
  count = var.namespace == "default" ? 1 : 0
  metadata {
    name = "default"
  }
}

locals {
  namespace_name = var.namespace == "default" ? data.kubernetes_namespace.redis[0].metadata[0].name : kubernetes_namespace.redis[0].metadata[0].name
  # Use provided version or null for latest
  chart_version = var.chart_version != "" ? var.chart_version : null
}

# Redis Helm Release
resource "helm_release" "redis" {
  name       = var.release_name
  chart      = "bitnami/redis"
  version    = var.chart_version != "" ? var.chart_version : "23.2.12"
  namespace  = local.namespace_name

  atomic            = true  # Critical: keep atomic for safety
  wait              = var.helm_wait_enabled
  wait_for_jobs     = var.helm_wait_for_jobs_enabled
  timeout           = 60  # Minimal timeout for Helm API calls
  reuse_values      = false
  force_update      = false
  cleanup_on_fail   = true
  dependency_update = true  # Update Helm repo before installing

  values = [
    yamlencode({
      architecture = var.architecture
      auth = {
        enabled = var.auth_enabled
        password = var.auth_enabled && var.auth_password != "" ? var.auth_password : null
      }
      master = {
        persistence = {
          enabled      = var.persistence_enabled
          storageClass = var.storage_class
          size         = var.storage_size
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
      }
      replica = {
        replicaCount = var.replica_count
        persistence = {
          enabled      = var.persistence_enabled
          storageClass = var.storage_class
          size         = var.storage_size
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
      }
    })
  ]

  depends_on = [
    kubernetes_namespace.redis,
    data.kubernetes_namespace.redis
  ]
}

