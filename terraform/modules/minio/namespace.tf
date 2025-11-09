# MinIO Namespace
resource "kubernetes_namespace" "minio" {
  metadata {
    name = var.namespace
    labels = {
      name = var.namespace
    }
  }
}

