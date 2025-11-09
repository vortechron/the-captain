variable "namespace" {
  description = "Kubernetes namespace for Loki"
  type        = string
  default     = "observability"
}

variable "chart_version" {
  description = "Loki Helm chart version"
  type        = string
  default     = "6.30.1"
}

variable "storage_class" {
  description = "Storage class for Loki persistent volume"
  type        = string
  default     = "managed-premium"
}

variable "storage_size" {
  description = "Size of the Loki persistent volume"
  type        = string
  default     = "3Gi"
}

variable "retention_period" {
  description = "Log retention period (e.g., 72h for 3 days)"
  type        = string
  default     = "72h"
}

variable "resources" {
  description = "Resource requests and limits for Loki container"
  type = object({
    requests = object({
      cpu    = string
      memory = string
    })
    limits = object({
      cpu    = string
      memory = string
    })
  })
  default = {
    requests = {
      cpu    = "100m"
      memory = "256Mi"
    }
    limits = {
      cpu    = "500m"
      memory = "512Mi"
    }
  }
}

variable "helm_wait_enabled" {
  description = "Enable wait for Helm release to be ready"
  type        = bool
  default     = true
}

variable "helm_wait_for_jobs_enabled" {
  description = "Enable wait for Helm jobs to complete"
  type        = bool
  default     = true
}

variable "helm_timeout" {
  description = "Timeout in seconds for Helm operations"
  type        = number
  default     = 600
}

