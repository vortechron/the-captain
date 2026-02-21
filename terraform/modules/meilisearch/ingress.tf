# MeiliSearch Ingress
resource "kubernetes_ingress_v1" "meilisearch_ingress" {
  metadata {
    name      = "meilisearch-ingress"
    namespace = kubernetes_namespace.meilisearch.metadata[0].name
    annotations = {
      "cert-manager.io/cluster-issuer" = var.cluster_issuer_name
      "kubernetes.io/ingress.class"    = "nginx"
    }
  }

  spec {
    ingress_class_name = "nginx"

    tls {
      hosts = [
        "meilisearch.aks.${var.domain}"
      ]
      secret_name = "meilisearch-tls"
    }

    rule {
      host = "meilisearch.aks.${var.domain}"
      http {
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = var.release_name
              port {
                number = 7700
              }
            }
          }
        }
      }
    }
  }

  depends_on = [helm_release.meilisearch]
}
