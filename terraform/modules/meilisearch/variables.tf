variable "namespace" {
  description = "Kubernetes namespace for MeiliSearch"
  type        = string
  default     = "meilisearch"
}

variable "release_name" {
  description = "Helm release name for MeiliSearch"
  type        = string
  default     = "meilisearch"
}

variable "chart_version" {
  description = "MeiliSearch Helm chart version"
  type        = string
  default     = ""
}

variable "domain" {
  description = "Base domain for MeiliSearch endpoint"
  type        = string
  default     = "terapeas.com"
}

variable "cluster_issuer_name" {
  description = "Name of the cert-manager ClusterIssuer to use"
  type        = string
  default     = "letsencrypt-prod"
}

variable "master_key" {
  description = "MeiliSearch master key for API authentication"
  type        = string
  sensitive   = true
}

variable "storage_class" {
  description = "Storage class for MeiliSearch persistent volume"
  type        = string
  default     = "managed-premium"
}

variable "storage_size" {
  description = "Size of the MeiliSearch persistent volume"
  type        = string
  default     = "10Gi"
}

variable "resources" {
  description = "Resource requests and limits for MeiliSearch container"
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
      cpu    = "250m"
      memory = "512Mi"
    }
    limits = {
      cpu    = "1000m"
      memory = "1Gi"
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
