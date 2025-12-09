# Cert-Manager ClusterIssuer (optional - only created if create_cluster_issuer is true)
resource "kubernetes_manifest" "cluster_issuer" {
  count = var.create_cluster_issuer ? 1 : 0

  manifest = {
    apiVersion = "cert-manager.io/v1"
    kind       = "ClusterIssuer"
    metadata = {
      name = var.cluster_issuer_name
    }
    spec = {
      acme = {
        email = var.cert_manager_email
        privateKeySecretRef = {
          name = "${var.cluster_issuer_name}-account-key"
        }
        server = "https://acme-v02.api.letsencrypt.org/directory"
        solvers = [
          {
            http01 = {
              ingress = {
                class = "nginx"
              }
            }
          }
        ]
      }
    }
  }
}

# MinIO Ingress
resource "kubernetes_ingress_v1" "minio_ingress" {
  metadata {
    name      = "minio-ingress"
    namespace = kubernetes_namespace.minio.metadata[0].name
    annotations = {
      "cert-manager.io/cluster-issuer"                    = var.cluster_issuer_name
      "kubernetes.io/ingress.class"                       = "nginx"
      "nginx.ingress.kubernetes.io/proxy-body-size"      = "100m"
      "nginx.ingress.kubernetes.io/proxy-read-timeout"   = "600"
      "nginx.ingress.kubernetes.io/proxy-send-timeout"   = "600"
      "nginx.ingress.kubernetes.io/client-max-body-size" = "100m"
      "nginx.ingress.kubernetes.io/proxy-buffering"      = "off"
    }
  }

  spec {
    ingress_class_name = "nginx"

    tls {
      hosts = [
        "minio.aks.${var.domain}",
        "minio.${var.domain}",
        "minio-console.aks.${var.domain}",
        "minio-console.${var.domain}"
      ]
      secret_name = "minio-tls"
    }

    rule {
      host = "minio.aks.${var.domain}"
      http {
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = kubernetes_service.minio_service.metadata[0].name
              port {
                number = 9000
              }
            }
          }
        }
      }
    }

    rule {
      host = "minio.${var.domain}"
      http {
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = kubernetes_service.minio_service.metadata[0].name
              port {
                number = 9000
              }
            }
          }
        }
      }
    }

    rule {
      host = "minio-console.aks.${var.domain}"
      http {
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = kubernetes_service.minio_console.metadata[0].name
              port {
                number = 9001
              }
            }
          }
        }
      }
    }

    rule {
      host = "minio-console.${var.domain}"
      http {
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = kubernetes_service.minio_console.metadata[0].name
              port {
                number = 9001
              }
            }
          }
        }
      }
    }
  }

  depends_on = [kubernetes_deployment.minio]
}

