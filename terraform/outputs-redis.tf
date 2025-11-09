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

