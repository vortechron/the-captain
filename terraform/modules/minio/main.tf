# MinIO Namespace
resource "kubernetes_namespace" "minio" {
  metadata {
    name = var.namespace
    labels = {
      name = var.namespace
    }
  }
}

# MinIO Secret
resource "kubernetes_secret" "minio_secret" {
  metadata {
    name      = "minio-secret"
    namespace = kubernetes_namespace.minio.metadata[0].name
  }

  type = "Opaque"

  data = {
    MINIO_ROOT_USER     = var.minio_root_user
    MINIO_ROOT_PASSWORD = var.minio_root_password
  }
}

# MinIO Persistent Volume Claim
resource "kubernetes_persistent_volume_claim" "minio_pvc" {
  metadata {
    name      = "minio-pvc"
    namespace = kubernetes_namespace.minio.metadata[0].name
  }

  spec {
    access_modes       = ["ReadWriteOnce"]
    storage_class_name = var.storage_class

    resources {
      requests = {
        storage = var.storage_size
      }
    }
  }

  # Don't wait for binding when using WaitForFirstConsumer storage class
  # The PVC will bind automatically when the pod starts
  wait_until_bound = false
}

# MinIO Deployment
resource "kubernetes_deployment" "minio" {
  metadata {
    name      = "minio"
    namespace = kubernetes_namespace.minio.metadata[0].name
    labels = {
      app = "minio"
    }
  }

  lifecycle {
    ignore_changes = [
      # Ignore changes to replicas that might be managed by HPA or manually
      spec[0].replicas,
    ]
  }

  spec {
    replicas = var.replicas

    selector {
      match_labels = {
        app = "minio"
      }
    }

    template {
      metadata {
        labels = {
          app = "minio"
        }
      }

      spec {
        container {
          name  = "minio"
          image = var.minio_image

          args = [
            "server",
            "/data",
            "--console-address",
            ":9001"
          ]

          env {
            name = "MINIO_ROOT_USER"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.minio_secret.metadata[0].name
                key  = "MINIO_ROOT_USER"
              }
            }
          }

          env {
            name = "MINIO_ROOT_PASSWORD"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.minio_secret.metadata[0].name
                key  = "MINIO_ROOT_PASSWORD"
              }
            }
          }

          port {
            name           = "api"
            container_port = 9000
          }

          port {
            name           = "console"
            container_port = 9001
          }

          volume_mount {
            name       = "data"
            mount_path = "/data"
          }

          resources {
            requests = {
              cpu    = var.resources.requests.cpu
              memory = var.resources.requests.memory
            }
            limits = {
              cpu    = var.resources.limits.cpu
              memory = var.resources.limits.memory
            }
          }

          liveness_probe {
            http_get {
              path = "/minio/health/live"
              port = 9000
            }
            initial_delay_seconds = 30
            period_seconds        = 20
          }

          readiness_probe {
            http_get {
              path = "/minio/health/ready"
              port = 9000
            }
            initial_delay_seconds = 5
            period_seconds        = 5
          }
        }

        # Prefer d4pool node for better resource distribution
        affinity {
          node_affinity {
            preferred_during_scheduling_ignored_during_execution {
              weight = 100
              preference {
                match_expressions {
                  key      = "kubernetes.azure.com/agentpool"
                  operator = "In"
                  values   = ["d4pool"]
                }
              }
            }
          }
        }

        volume {
          name = "data"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim.minio_pvc.metadata[0].name
          }
        }
      }
    }
  }
}

# MinIO API Service
resource "kubernetes_service" "minio_service" {
  metadata {
    name      = "minio-service"
    namespace = kubernetes_namespace.minio.metadata[0].name
    labels = {
      app = "minio"
    }
  }

  spec {
    selector = {
      app = "minio"
    }

    port {
      name        = "api"
      port        = 9000
      target_port = 9000
      protocol    = "TCP"
    }

    port {
      name        = "console"
      port        = 9001
      target_port = 9001
      protocol    = "TCP"
    }

    type = "ClusterIP"
  }
}

# MinIO Console Service
resource "kubernetes_service" "minio_console" {
  metadata {
    name      = "minio-console"
    namespace = kubernetes_namespace.minio.metadata[0].name
    labels = {
      app     = "minio"
      service = "console"
    }
  }

  spec {
    selector = {
      app = "minio"
    }

    port {
      name        = "console"
      port        = 9001
      target_port = 9001
      protocol    = "TCP"
    }

    type = "ClusterIP"
  }
}

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
        "minio-console.aks.${var.domain}"
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
  }

  depends_on = [kubernetes_deployment.minio]
}

