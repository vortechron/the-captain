# MeiliSearch Configuration
variable "meilisearch_enabled" {
  description = "Enable MeiliSearch deployment"
  type        = bool
  default     = true
}

variable "meilisearch_namespace" {
  description = "Kubernetes namespace for MeiliSearch"
  type        = string
  default     = "meilisearch"
}

variable "meilisearch_release_name" {
  description = "Helm release name for MeiliSearch"
  type        = string
  default     = "meilisearch"
}

variable "meilisearch_chart_version" {
  description = "MeiliSearch Helm chart version"
  type        = string
  default     = ""
}

variable "meilisearch_domain" {
  description = "Base domain for MeiliSearch endpoint"
  type        = string
  default     = "terapeas.com"
}

variable "meilisearch_cluster_issuer_name" {
  description = "Name of the cert-manager ClusterIssuer to use for MeiliSearch"
  type        = string
  default     = "letsencrypt-prod"
}

variable "meilisearch_master_key" {
  description = "MeiliSearch master key for API authentication"
  type        = string
  sensitive   = true
  default     = "msk-YjR3dE9wNmhLcVd4ZnNhQmN2TXpOeUF0UWVSdFVK"
}

variable "meilisearch_storage_class" {
  description = "Storage class for MeiliSearch persistent volume"
  type        = string
  default     = "managed-premium"
}

variable "meilisearch_storage_size" {
  description = "Size of the MeiliSearch persistent volume"
  type        = string
  default     = "10Gi"
}

variable "meilisearch_resources" {
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
