output "namespace" {
  description = "MinIO namespace name"
  value       = kubernetes_namespace.minio.metadata[0].name
}

output "minio_api_endpoint" {
  description = "MinIO API endpoint URL"
  value       = "https://minio.aks.${var.domain}"
}

output "minio_console_endpoint" {
  description = "MinIO Console endpoint URL"
  value       = "https://minio-console.aks.${var.domain}"
}

output "service_name" {
  description = "MinIO API service name"
  value       = kubernetes_service.minio_service.metadata[0].name
}

output "console_service_name" {
  description = "MinIO Console service name"
  value       = kubernetes_service.minio_console.metadata[0].name
}

output "ingress_name" {
  description = "MinIO ingress name"
  value       = kubernetes_ingress_v1.minio_ingress.metadata[0].name
}

output "cluster_issuer_name" {
  description = "Name of the ClusterIssuer being used"
  value       = var.cluster_issuer_name
}

