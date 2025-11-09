# Grafana Namespace
resource "kubernetes_namespace" "grafana" {
  metadata {
    name = var.namespace
    labels = {
      name = var.namespace
    }
  }
}

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

# Grafana Ingress
resource "kubernetes_ingress_v1" "grafana_ingress" {
  metadata {
    name      = "grafana-ingress"
    namespace = kubernetes_namespace.grafana.metadata[0].name
    annotations = {
      "cert-manager.io/cluster-issuer"        = var.cluster_issuer_name
      "kubernetes.io/ingress.class"           = "nginx"
    }
  }

  spec {
    ingress_class_name = "nginx"

    tls {
      hosts = [
        "grafana.aks.${var.domain}"
      ]
      secret_name = "grafana-tls"
    }

    rule {
      host = "grafana.aks.${var.domain}"
      http {
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = "grafana"
              port {
                number = 80
              }
            }
          }
        }
      }
    }
  }

  depends_on = [helm_release.grafana]
}

# Grafana Loki Datasource ConfigMap
resource "kubernetes_config_map" "grafana_datasource_loki" {
  count = var.enable_loki_datasource ? 1 : 0

  metadata {
    name      = "grafana-datasource-loki"
    namespace = kubernetes_namespace.grafana.metadata[0].name
    labels = {
      grafana_datasource = "1"
    }
  }

  data = {
    "loki.yaml" = yamlencode({
      apiVersion = 1
      datasources = [
        {
          name      = "Loki"
          type      = "loki"
          access    = "proxy"
          url       = var.loki_datasource_url
          isDefault = true
          editable  = true
        }
      ]
    })
  }

  depends_on = [helm_release.grafana]
}

# Grafana Prometheus Datasource ConfigMap
resource "kubernetes_config_map" "grafana_datasource_prometheus" {
  count = var.enable_prometheus_datasource ? 1 : 0

  metadata {
    name      = "grafana-datasource-prometheus"
    namespace = kubernetes_namespace.grafana.metadata[0].name
    labels = {
      grafana_datasource = "1"
    }
  }

  data = {
    "prometheus.yaml" = yamlencode({
      apiVersion = 1
      datasources = [
        {
          name      = "Prometheus-MySQL"
          type      = "prometheus"
          access    = "proxy"
          url       = var.prometheus_datasource_url
          isDefault = false
          editable  = true
          jsonData = {
            timeInterval = "30s"
          }
        }
      ]
    })
  }

  depends_on = [helm_release.grafana]
}

