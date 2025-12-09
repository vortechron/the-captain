# Promtail Configuration
variable "promtail_enabled" {
  description = "Enable Promtail deployment"
  type        = bool
  default     = true
}

variable "promtail_namespace" {
  description = "Kubernetes namespace for Promtail"
  type        = string
  default     = "observability"
}

variable "promtail_chart_version" {
  description = "Promtail Helm chart version"
  type        = string
  default     = "6.15.4"
}

variable "promtail_loki_url" {
  description = "Loki URL for Promtail (leave empty to auto-detect from Loki module)"
  type        = string
  default     = ""
}





