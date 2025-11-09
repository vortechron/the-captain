variable "namespace" {
  description = "Kubernetes namespace for Prometheus"
  type        = string
  default     = "observability"
}

variable "chart_version" {
  description = "Prometheus Helm chart version (leave empty for latest)"
  type        = string
  default     = ""
}

variable "storage_class" {
  description = "Storage class for Prometheus persistent volume"
  type        = string
  default     = "managed-premium"
}

variable "storage_size" {
  description = "Size of the Prometheus persistent volume"
  type        = string
  default     = "10Gi"
}

variable "retention_time" {
  description = "Prometheus data retention time (e.g., 7d)"
  type        = string
  default     = "7d"
}

variable "resources" {
  description = "Resource requests and limits for Prometheus server"
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
      cpu    = "200m"
      memory = "512Mi"
    }
    limits = {
      cpu    = "1000m"
      memory = "2Gi"
    }
  }
}

variable "enable_node_exporter" {
  description = "Enable node-exporter (included in Prometheus chart)"
  type        = bool
  default     = true
}

variable "enable_kube_state_metrics" {
  description = "Enable kube-state-metrics (included in Prometheus chart)"
  type        = bool
  default     = true
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

