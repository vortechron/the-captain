variable "namespace" {
  description = "Kubernetes namespace for Redis"
  type        = string
  default     = "default"
}

variable "release_name" {
  description = "Helm release name for Redis"
  type        = string
  default     = "redis"
}

variable "chart_version" {
  description = "Redis Helm chart version (leave empty for latest)"
  type        = string
  default     = ""
}

variable "architecture" {
  description = "Redis architecture: 'standalone' or 'replication'"
  type        = string
  default     = "standalone"
  
  validation {
    condition     = contains(["standalone", "replication"], var.architecture)
    error_message = "Architecture must be either 'standalone' or 'replication'."
  }
}

variable "auth_enabled" {
  description = "Enable Redis authentication"
  type        = bool
  default     = false
}

variable "auth_password" {
  description = "Redis password (only used if auth_enabled is true, leave empty to auto-generate)"
  type        = string
  sensitive   = true
  default     = ""
}

variable "persistence_enabled" {
  description = "Enable persistent storage for Redis"
  type        = bool
  default     = true
}

variable "storage_class" {
  description = "Storage class for Redis persistent volume"
  type        = string
  default     = "managed-premium"
}

variable "storage_size" {
  description = "Size of the Redis persistent volume"
  type        = string
  default     = "20Gi"
}

variable "replica_count" {
  description = "Number of Redis replicas (only used if architecture is 'replication')"
  type        = number
  default     = 2
}

variable "resources" {
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

variable "helm_wait_enabled" {
  description = "Enable wait for Helm releases to be ready"
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

variable "master_command" {
  description = "Custom command for Redis master (for performance tuning)"
  type        = string
  default     = ""
}

variable "disable_commands" {
  description = "List of Redis commands to disable (for security/performance)"
  type        = list(string)
  default     = []
}

variable "common_configuration" {
  description = "Common Redis configuration (for performance tuning)"
  type        = string
  default     = <<-EOT
    # Performance tuning for heavy traffic
    tcp-keepalive 60
    timeout 300
    tcp-backlog 511
    # Memory optimization
    save ""
    # Disable AOF for better performance (use persistence instead)
    appendonly no
  EOT
}

variable "maxmemory" {
  description = "Maximum memory Redis can use (e.g., '2gb'). Leave empty to use container memory limit"
  type        = string
  default     = ""
}

variable "maxmemory_policy" {
  description = "Redis eviction policy when maxmemory is reached"
  type        = string
  default     = "allkeys-lru"
}

