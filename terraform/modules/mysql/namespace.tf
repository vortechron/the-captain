# MySQL Namespace
resource "kubernetes_namespace" "mysql" {
  metadata {
    name = var.namespace
    labels = {
      name = var.namespace
    }
  }
}

