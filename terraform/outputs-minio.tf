# MinIO Outputs
output "minio_api_endpoint" {
  description = "MinIO API endpoint URL"
  value       = var.minio_enabled ? module.minio[0].minio_api_endpoint : null
}

output "minio_console_endpoint" {
  description = "MinIO Console endpoint URL"
  value       = var.minio_enabled ? module.minio[0].minio_console_endpoint : null
}

output "minio_namespace" {
  description = "MinIO namespace name"
  value       = var.minio_enabled ? module.minio[0].namespace : null
}

output "minio_ingress_name" {
  description = "MinIO ingress resource name"
  value       = var.minio_enabled ? module.minio[0].ingress_name : null
}

