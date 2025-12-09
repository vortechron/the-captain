# Ingress NGINX Outputs
output "ingress_nginx_loadbalancer_ip_command" {
  description = "Command to get the NGINX Ingress Controller LoadBalancer IP"
  value       = var.ingress_nginx_enabled ? "kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}'" : null
}

output "ingress_nginx_service_name" {
  description = "Name of the NGINX Ingress Controller service"
  value       = var.ingress_nginx_enabled ? "ingress-nginx-controller" : null
}

output "ingress_nginx_namespace" {
  description = "Namespace where NGINX Ingress Controller is installed"
  value       = var.ingress_nginx_enabled ? "ingress-nginx" : null
}





