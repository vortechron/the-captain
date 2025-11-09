output "namespace" {
  description = "Redis namespace name"
  value       = var.namespace
}

output "release_name" {
  description = "Redis Helm release name"
  value       = helm_release.redis.name
}

output "service_name" {
  description = "Redis master service name"
  value       = "${var.release_name}-master"
}

output "service_endpoint" {
  description = "Redis master service endpoint (internal)"
  value       = "${var.release_name}-master.${var.namespace}.svc.cluster.local:6379"
}

output "port" {
  description = "Redis port"
  value       = 6379
}

output "auth_enabled" {
  description = "Whether Redis authentication is enabled"
  value       = var.auth_enabled
}

output "password_command" {
  description = "Command to retrieve Redis password (if auth is enabled)"
  value       = var.auth_enabled ? "kubectl get secret --namespace ${var.namespace} ${var.release_name} -o jsonpath='{.data.redis-password}' | base64 -d" : null
}

output "port_forward_command" {
  description = "Command to port-forward to Redis"
  value       = "kubectl port-forward --namespace ${var.namespace} svc/${var.release_name}-master 6379:6379"
}

