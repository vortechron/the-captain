output "resource_group_name" {
  description = "Name of the resource group"
  value       = azurerm_resource_group.main.name
}

output "aks_cluster_name" {
  description = "Name of the AKS cluster"
  value       = azurerm_kubernetes_cluster.main.name
}

output "aks_cluster_fqdn" {
  description = "FQDN of the AKS cluster"
  value       = azurerm_kubernetes_cluster.main.fqdn
}

output "aks_cluster_kubeconfig_command" {
  description = "Command to retrieve kubeconfig for AKS cluster"
  value       = "az aks get-credentials --resource-group ${azurerm_resource_group.main.name} --name ${azurerm_kubernetes_cluster.main.name}"
}

output "aks_cluster_portal_url" {
  description = "Azure Portal URL for the AKS cluster"
  value       = "https://portal.azure.com/#@/resource/subscriptions/${var.subscription_id}/resourceGroups/${azurerm_resource_group.main.name}/providers/Microsoft.ContainerService/managedClusters/${azurerm_kubernetes_cluster.main.name}"
}

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

# MySQL Outputs
output "mysql_namespace" {
  description = "MySQL namespace name"
  value       = var.mysql_enabled ? module.mysql[0].namespace : null
}

output "mysql_cluster_name" {
  description = "Percona XtraDB Cluster name"
  value       = var.mysql_enabled ? module.mysql[0].cluster_name : null
}

output "mysql_service_endpoint" {
  description = "MySQL HAProxy service endpoint (internal)"
  value       = var.mysql_enabled ? module.mysql[0].service_endpoint : null
}

output "mysql_service_name" {
  description = "MySQL HAProxy service name"
  value       = var.mysql_enabled ? module.mysql[0].service_name : null
}

output "mysql_secret_name" {
  description = "Name of the secrets containing MySQL passwords"
  value       = var.mysql_enabled ? module.mysql[0].secret_name : null
}

output "mysql_root_password_command" {
  description = "Command to retrieve MySQL root password"
  value       = var.mysql_enabled ? "kubectl get secret ${module.mysql[0].secret_name} -n ${module.mysql[0].namespace} -o jsonpath='{.data.root}' | base64 -d" : null
}

output "mysql_port_forward_command" {
  description = "Command to port-forward to MySQL"
  value       = var.mysql_enabled ? "kubectl port-forward svc/${module.mysql[0].service_name} 3306:3306 -n ${module.mysql[0].namespace}" : null
}

output "mysql_monitoring_enabled" {
  description = "Whether MySQL monitoring is enabled"
  value       = var.mysql_enabled && var.mysql_monitoring_enabled ? module.mysql[0].monitoring_enabled : null
}

output "mysql_monitoring_service_endpoint" {
  description = "MySQL Exporter service endpoint"
  value       = var.mysql_enabled && var.mysql_monitoring_enabled ? module.mysql[0].monitoring_service_endpoint : null
}

# Redis Outputs
output "redis_namespace" {
  description = "Redis namespace name"
  value       = var.redis_enabled ? module.redis[0].namespace : null
}

output "redis_service_name" {
  description = "Redis master service name"
  value       = var.redis_enabled ? module.redis[0].service_name : null
}

output "redis_service_endpoint" {
  description = "Redis master service endpoint (internal)"
  value       = var.redis_enabled ? module.redis[0].service_endpoint : null
}

output "redis_port" {
  description = "Redis port"
  value       = var.redis_enabled ? module.redis[0].port : null
}

output "redis_auth_enabled" {
  description = "Whether Redis authentication is enabled"
  value       = var.redis_enabled ? module.redis[0].auth_enabled : null
}

output "redis_password_command" {
  description = "Command to retrieve Redis password (if auth is enabled)"
  value       = var.redis_enabled ? module.redis[0].password_command : null
}

output "redis_port_forward_command" {
  description = "Command to port-forward to Redis"
  value       = var.redis_enabled ? module.redis[0].port_forward_command : null
}
