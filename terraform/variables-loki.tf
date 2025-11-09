# Loki Configuration
variable "loki_enabled" {
  description = "Enable Loki deployment"
  type        = bool
  default     = true
}

variable "loki_namespace" {
  description = "Kubernetes namespace for Loki"
  type        = string
  default     = "observability"
}

variable "loki_chart_version" {
  description = "Loki Helm chart version"
  type        = string
  default     = "6.30.1"
}

variable "loki_storage_class" {
  description = "Storage class for Loki persistent volume"
  type        = string
  default     = "managed-premium"
}

variable "loki_storage_size" {
  description = "Size of the Loki persistent volume"
  type        = string
  default     = "3Gi"
}

variable "loki_retention_period" {
  description = "Loki log retention period (e.g., 72h for 3 days)"
  type        = string
  default     = "72h"
}

