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





