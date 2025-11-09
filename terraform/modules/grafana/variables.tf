variable "domain" {
  description = "Base domain for Grafana endpoint"
  type        = string
  default     = "terapeas.com"
}

variable "chart_version" {
  description = "Grafana Helm chart version"
  type        = string
  default     = "9.2.7"
}

variable "cluster_issuer_name" {
  description = "Name of the cert-manager ClusterIssuer to use"
  type        = string
  default     = "letsencrypt-prod"
}

variable "namespace" {
  description = "Kubernetes namespace for Grafana"
  type        = string
  default     = "observability"
}

variable "storage_class" {
  description = "Storage class for Grafana persistent volume"
  type        = string
  default     = "managed-premium"
}

variable "storage_size" {
  description = "Size of the Grafana persistent volume"
  type        = string
  default     = "10Gi"
}

variable "admin_user" {
  description = "Grafana admin username"
  type        = string
  default     = "admin"
}

variable "admin_password" {
  description = "Grafana admin password (leave empty to auto-generate)"
  type        = string
  sensitive   = true
  default     = ""
}

variable "resources" {
  description = "Resource requests and limits for Grafana container"
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

variable "loki_datasource_url" {
  description = "Loki datasource URL"
  type        = string
  default     = "http://loki-gateway.observability.svc.cluster.local/"
}

variable "prometheus_datasource_url" {
  description = "Prometheus datasource URL"
  type        = string
  default     = "http://prometheus.observability.svc.cluster.local:9090"
}

variable "enable_loki_datasource" {
  description = "Enable Loki datasource provisioning"
  type        = bool
  default     = true
}

variable "enable_prometheus_datasource" {
  description = "Enable Prometheus datasource provisioning"
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

