# MeiliSearch Outputs
output "meilisearch_endpoint" {
  description = "MeiliSearch external endpoint URL"
  value       = var.meilisearch_enabled ? module.meilisearch[0].endpoint : null
}

output "meilisearch_namespace" {
  description = "MeiliSearch namespace name"
  value       = var.meilisearch_enabled ? module.meilisearch[0].namespace : null
}

output "meilisearch_service_endpoint" {
  description = "MeiliSearch internal service endpoint"
  value       = var.meilisearch_enabled ? module.meilisearch[0].service_endpoint : null
}

output "meilisearch_ingress_name" {
  description = "MeiliSearch ingress resource name"
  value       = var.meilisearch_enabled ? module.meilisearch[0].ingress_name : null
}

output "meilisearch_port_forward_command" {
  description = "Command to port-forward to MeiliSearch"
  value       = var.meilisearch_enabled ? module.meilisearch[0].port_forward_command : null
}
