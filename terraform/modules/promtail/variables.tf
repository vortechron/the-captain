variable "namespace" {
  description = "Kubernetes namespace for Promtail"
  type        = string
  default     = "observability"
}

variable "chart_version" {
  description = "Promtail Helm chart version"
  type        = string
  default     = "6.15.4"
}

variable "loki_url" {
  description = "Loki service URL for log pushing"
  type        = string
  default     = "http://loki-gateway.observability.svc.cluster.local/loki/api/v1/push"
}

variable "resources" {
  description = "Resource requests and limits for Promtail container"
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
      memory = "128Mi"
    }
    limits = {
      cpu    = "200m"
      memory = "256Mi"
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

