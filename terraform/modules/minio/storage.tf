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

