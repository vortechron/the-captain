output "namespace" {
  description = "Promtail namespace name"
  value       = var.namespace
}

output "helm_release_name" {
  description = "Promtail Helm release name"
  value       = helm_release.promtail.name
}




