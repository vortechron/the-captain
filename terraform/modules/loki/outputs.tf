output "namespace" {
  description = "Loki namespace name"
  value       = var.namespace
}

output "service_name" {
  description = "Loki gateway service name"
  value       = "loki-gateway"
}

output "service_url" {
  description = "Loki gateway service URL"
  value       = "http://loki-gateway.${var.namespace}.svc.cluster.local"
}

output "helm_release_name" {
  description = "Loki Helm release name"
  value       = helm_release.loki.name
}

