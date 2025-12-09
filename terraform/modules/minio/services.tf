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





