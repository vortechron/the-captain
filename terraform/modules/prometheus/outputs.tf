output "namespace" {
  description = "Prometheus namespace name"
  value       = var.namespace
}

output "service_name" {
  description = "Prometheus server service name"
  value       = "prometheus-server"
}

output "service_url" {
  description = "Prometheus server service URL"
  value       = "http://prometheus-server.${var.namespace}.svc.cluster.local"
}

output "helm_release_name" {
  description = "Prometheus Helm release name"
  value       = helm_release.prometheus.name
}








