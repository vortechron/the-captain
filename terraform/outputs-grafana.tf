# Grafana Outputs
output "grafana_endpoint" {
  description = "Grafana endpoint URL"
  value       = var.grafana_enabled ? module.grafana[0].grafana_endpoint : null
}

output "grafana_namespace" {
  description = "Grafana namespace name"
  value       = var.grafana_enabled ? module.grafana[0].namespace : null
}

output "grafana_ingress_name" {
  description = "Grafana ingress resource name"
  value       = var.grafana_enabled ? module.grafana[0].ingress_name : null
}

output "grafana_admin_password_command" {
  description = "Command to retrieve Grafana admin password"
  value       = var.grafana_enabled ? module.grafana[0].admin_password_command : null
}

output "grafana_admin_user_command" {
  description = "Command to retrieve Grafana admin username"
  value       = var.grafana_enabled ? module.grafana[0].admin_user_command : null
}

output "grafana_port_forward_command" {
  description = "Command to port-forward to Grafana"
  value       = var.grafana_enabled ? module.grafana[0].port_forward_command : null
}

