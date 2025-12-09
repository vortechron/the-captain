# Loki Outputs
output "loki_namespace" {
  description = "Loki namespace name"
  value       = var.loki_enabled ? module.loki[0].namespace : null
}

output "loki_service_url" {
  description = "Loki gateway service URL"
  value       = var.loki_enabled ? module.loki[0].service_url : null
}

# Promtail Outputs
output "promtail_namespace" {
  description = "Promtail namespace name"
  value       = var.promtail_enabled ? module.promtail[0].namespace : null
}

# Prometheus Outputs
output "prometheus_namespace" {
  description = "Prometheus namespace name"
  value       = var.prometheus_enabled ? module.prometheus[0].namespace : null
}

output "prometheus_service_url" {
  description = "Prometheus server service URL"
  value       = var.prometheus_enabled ? module.prometheus[0].service_url : null
}





