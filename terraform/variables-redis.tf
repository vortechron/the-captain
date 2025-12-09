# Redis Configuration
variable "redis_enabled" {
  description = "Enable Redis deployment"
  type        = bool
  default     = true
}

variable "redis_namespace" {
  description = "Kubernetes namespace for Redis"
  type        = string
  default     = "default"
}

variable "redis_release_name" {
  description = "Helm release name for Redis"
  type        = string
  default     = "redis"
}

variable "redis_chart_version" {
  description = "Redis Helm chart version (leave empty for latest)"
  type        = string
  default     = ""
}

variable "redis_architecture" {
  description = "Redis architecture: 'standalone' or 'replication'"
  type        = string
  default     = "replication"
}

variable "redis_auth_enabled" {
  description = "Enable Redis authentication"
  type        = bool
  default     = true
}

variable "redis_auth_password" {
  description = "Redis password (only used if auth_enabled is true, leave empty to auto-generate)"
  type        = string
  sensitive   = true
  default     = ""
}

variable "redis_persistence_enabled" {
  description = "Enable persistent storage for Redis"
  type        = bool
  default     = true
}

variable "redis_storage_class" {
  description = "Storage class for Redis persistent volume"
  type        = string
  default     = "managed-premium"
}

variable "redis_storage_size" {
  description = "Size of the Redis persistent volume"
  type        = string
  default     = "20Gi"
}

variable "redis_replica_count" {
  description = "Number of Redis replicas (only used if architecture is 'replication')"
  type        = number
  default     = 2
}

variable "redis_resources" {
  description = "Resource requests and limits for Redis containers"
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
      cpu    = "500m"
      memory = "1Gi"
    }
    limits = {
      cpu    = "2000m"
      memory = "4Gi"
    }
  }
}





