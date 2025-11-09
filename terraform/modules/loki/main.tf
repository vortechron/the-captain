# Loki Namespace (reuse observability namespace)
data "kubernetes_namespace" "observability" {
  metadata {
    name = var.namespace
  }
}

# Helm Release for Loki
resource "helm_release" "loki" {
  name       = "loki"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "loki"
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
      deploymentMode = "SingleBinary"

      loki = {
        auth_enabled = false
        commonConfig = {
          replication_factor = 1
        }
        storage = {
          type = "filesystem"
          filesystem = {
            chunks_directory = "/var/loki/chunks"
            rules_directory  = "/var/loki/rules"
          }
        }
        schemaConfig = {
          configs = [
            {
              from        = "2020-10-24"
              store       = "boltdb-shipper"
              object_store = "filesystem"
              schema      = "v11"
              index = {
                prefix = "index_"
                period = "24h"
              }
            }
          ]
        }
        limits_config = {
          retention_period      = var.retention_period
          reject_old_samples    = true
          reject_old_samples_max_age = "168h"
          allow_structured_metadata = false
        }
      }

      singleBinary = {
        replicas = 1
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
      }

      gateway = {
        enabled  = true
        replicas = 1
      }

      # Explicitly disable all distributed components
      backend = {
        replicas = 0
      }
      read = {
        replicas = 0
      }
      write = {
        replicas = 0
      }
      querier = {
        replicas = 0
      }
      queryFrontend = {
        replicas = 0
      }
      ingester = {
        replicas = 0
      }
      distributor = {
        replicas = 0
      }
      indexGateway = {
        replicas = 0
      }
      compactor = {
        replicas = 0
      }
      ruler = {
        replicas = 0
      }

      # Disable all caching components
      chunksCache = {
        enabled = false
      }
      resultsCache = {
        enabled = false
      }

      # Disable monitoring components
      monitoring = {
        selfMonitoring = {
          enabled = false
          grafanaAgent = {
            installOperator = false
          }
        }
        serviceMonitor = {
          enabled = false
        }
        lokiCanary = {
          enabled = false
        }
      }

      lokiCanary = {
        enabled = false
      }

      test = {
        enabled = false
      }

      minio = {
        enabled = false
      }
    })
  ]

  depends_on = [data.kubernetes_namespace.observability]
}

