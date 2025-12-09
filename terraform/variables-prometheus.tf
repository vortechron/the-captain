# Prometheus Configuration
variable "prometheus_enabled" {
  description = "Enable Prometheus deployment"
  type        = bool
  default     = true
}

variable "prometheus_namespace" {
  description = "Kubernetes namespace for Prometheus"
  type        = string
  default     = "observability"
}

variable "prometheus_chart_version" {
  description = "Prometheus Helm chart version (leave empty for latest)"
  type        = string
  default     = ""
}

variable "prometheus_storage_class" {
  description = "Storage class for Prometheus persistent volume"
  type        = string
  default     = "managed-premium"
}

variable "prometheus_storage_size" {
  description = "Size of the Prometheus persistent volume"
  type        = string
  default     = "10Gi"
}

variable "prometheus_retention_time" {
  description = "Prometheus data retention time (e.g., 7d)"
  type        = string
  default     = "7d"
}

variable "prometheus_enable_node_exporter" {
  description = "Enable node-exporter (included in Prometheus chart)"
  type        = bool
  default     = true
}

variable "prometheus_enable_kube_state_metrics" {
  description = "Enable kube-state-metrics (included in Prometheus chart)"
  type        = bool
  default     = true
}





