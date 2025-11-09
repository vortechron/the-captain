output "namespace" {
  description = "Grafana namespace name"
  value       = kubernetes_namespace.grafana.metadata[0].name
}

output "grafana_endpoint" {
  description = "Grafana endpoint URL"
  value       = "https://grafana.aks.${var.domain}"
}

output "service_name" {
  description = "Grafana service name"
  value       = "grafana"
}

output "ingress_name" {
  description = "Grafana ingress name"
  value       = kubernetes_ingress_v1.grafana_ingress.metadata[0].name
}

output "admin_password_command" {
  description = "Command to retrieve Grafana admin password"
  value       = "kubectl get secret --namespace ${kubernetes_namespace.grafana.metadata[0].name} grafana -o jsonpath=\"{.data.admin-password}\" | base64 --decode"
}

output "admin_user_command" {
  description = "Command to retrieve Grafana admin username"
  value       = "kubectl get secret --namespace ${kubernetes_namespace.grafana.metadata[0].name} grafana -o jsonpath=\"{.data.admin-user}\" | base64 --decode"
}

output "port_forward_command" {
  description = "Command to port-forward to Grafana"
  value       = "kubectl port-forward -n ${kubernetes_namespace.grafana.metadata[0].name} svc/grafana 3000:80"
}

