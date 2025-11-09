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

