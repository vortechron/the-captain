# Grafana Namespace
resource "kubernetes_namespace" "grafana" {
  metadata {
    name = var.namespace
    labels = {
      name = var.namespace
    }
  }
}





