output "namespace" {
  description = "MySQL namespace name"
  value       = kubernetes_namespace.mysql.metadata[0].name
}

output "cluster_name" {
  description = "Percona XtraDB Cluster name"
  value       = var.cluster_name
}

output "service_endpoint" {
  description = "MySQL HAProxy service endpoint (internal)"
  value       = "${var.cluster_name}-pxc-db-haproxy.${var.namespace}.svc.cluster.local:3306"
}

output "service_name" {
  description = "MySQL HAProxy service name"
  value       = "${var.cluster_name}-pxc-db-haproxy"
}

output "operator_release_name" {
  description = "Percona Operator Helm release name"
  value       = helm_release.pxc_operator.name
}

output "cluster_release_name" {
  description = "Percona XtraDB Cluster Helm release name"
  value       = helm_release.pxc_cluster.name
}

output "secret_name" {
  description = "Name of the secrets containing MySQL passwords"
  value       = "${var.cluster_name}-pxc-db-secrets"
}

output "backup_enabled" {
  description = "Whether backups are enabled"
  value       = var.backup_enabled
}

output "backup_storage_name" {
  description = "Name of the backup storage configuration"
  value       = var.backup_enabled ? "minio-storage" : null
}

output "monitoring_enabled" {
  description = "Whether monitoring is enabled"
  value       = var.monitoring_enabled
}

output "monitoring_service_endpoint" {
  description = "MySQL Exporter service endpoint"
  value       = var.monitoring_enabled ? "mysql-exporter.${var.namespace}.svc.cluster.local:9104" : null
}

output "monitoring_service_name" {
  description = "MySQL Exporter service name"
  value       = var.monitoring_enabled ? "mysql-exporter" : null
}

