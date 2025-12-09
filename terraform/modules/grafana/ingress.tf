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





