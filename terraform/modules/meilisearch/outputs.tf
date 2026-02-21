output "namespace" {
  description = "MeiliSearch namespace name"
  value       = kubernetes_namespace.meilisearch.metadata[0].name
}

output "release_name" {
  description = "MeiliSearch Helm release name"
  value       = helm_release.meilisearch.name
}

output "service_name" {
  description = "MeiliSearch service name"
  value       = var.release_name
}

output "service_endpoint" {
  description = "MeiliSearch internal service endpoint"
  value       = "${var.release_name}.${kubernetes_namespace.meilisearch.metadata[0].name}.svc.cluster.local:7700"
}

output "endpoint" {
  description = "MeiliSearch external endpoint URL"
  value       = "https://meilisearch.aks.${var.domain}"
}

output "port_forward_command" {
  description = "Command to port-forward to MeiliSearch"
  value       = "kubectl port-forward -n ${kubernetes_namespace.meilisearch.metadata[0].name} svc/${var.release_name} 7700:7700"
}

output "ingress_name" {
  description = "MeiliSearch ingress name"
  value       = kubernetes_ingress_v1.meilisearch_ingress.metadata[0].name
}
