variable "namespace" {
  description = "Kubernetes namespace for MySQL"
  type        = string
  default     = "db"
}

variable "cluster_name" {
  description = "Name of the Percona XtraDB Cluster"
  type        = string
  default     = "cluster1"
}

variable "storage_class" {
  description = "Storage class for MySQL persistent volumes"
  type        = string
  default     = "managed-premium"
}

variable "storage_size" {
  description = "Size of the MySQL persistent volume per node"
  type        = string
  default     = "20Gi"
}

variable "operator_chart_version" {
  description = "Percona Operator Helm chart version (leave empty for latest)"
  type        = string
  default     = ""
}

variable "cluster_chart_version" {
  description = "Percona XtraDB Cluster Helm chart version (leave empty for latest)"
  type        = string
  default     = ""
}

variable "pxc_size" {
  description = "Number of MySQL nodes in the cluster"
  type        = number
  default     = 1
}

variable "pxc_image_tag" {
  description = "Percona XtraDB Cluster image tag"
  type        = string
  default     = "8.0.35-27.1"
}

variable "pxc_resources" {
  description = "Resource requests and limits for MySQL pods"
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
      cpu    = "1000m"
      memory = "2Gi"
    }
    limits = {
      cpu    = "2000m"
      memory = "4Gi"
    }
  }
}

variable "haproxy_size" {
  description = "Number of HAProxy replicas"
  type        = number
  default     = 1
}

variable "haproxy_image_tag" {
  description = "HAProxy image tag"
  type        = string
  default     = "1.14.0-haproxy"
}

variable "haproxy_resources" {
  description = "Resource requests and limits for HAProxy pods"
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
      memory = "1Gi"
    }
  }
}

variable "backup_enabled" {
  description = "Enable automated backups to MinIO"
  type        = bool
  default     = true
}

variable "backup_image_tag" {
  description = "Percona XtraBackup image tag"
  type        = string
  default     = "8.0.35-33.1"
}

variable "backup_schedule" {
  description = "Cron schedule for daily backups"
  type        = string
  default     = "0 2 * * *" # 2 AM UTC daily
}

variable "backup_retention_days" {
  description = "Number of days to keep backups"
  type        = number
  default     = 7
}

variable "backup_resources" {
  description = "Resource requests and limits for backup jobs"
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

variable "backup_timeout_seconds" {
  description = "Timeout in seconds for backup operations"
  type        = number
  default     = 7200 # 2 hours (increased to handle Galera connection timeouts)
}

variable "minio_endpoint_url" {
  description = "MinIO S3 endpoint URL"
  type        = string
  default     = "https://minio.aks.terapeas.com"
}

variable "minio_bucket" {
  description = "MinIO bucket name for backups"
  type        = string
  default     = "db-backup"
}

variable "minio_region" {
  description = "MinIO region"
  type        = string
  default     = "us-east-1"
}

variable "minio_access_key_id" {
  description = "MinIO access key ID for backups"
  type        = string
  sensitive   = true
  default     = "minioadmin"
}

variable "minio_secret_access_key" {
  description = "MinIO secret access key for backups"
  type        = string
  sensitive   = true
  default     = "Mpft0qBAEX2yIFXCqe/Ez5kAXZ89cabLEzI90jMtCRg="
}

variable "root_password" {
  description = "MySQL root password (leave empty to auto-generate)"
  type        = string
  sensitive   = true
  default     = ""
}

variable "monitoring_enabled" {
  description = "Enable MySQL monitoring with Prometheus exporter"
  type        = bool
  default     = true
}

variable "monitoring_user" {
  description = "MySQL user for monitoring (exporter)"
  type        = string
  default     = "exporter"
}

variable "monitoring_password" {
  description = "Password for MySQL monitoring user"
  type        = string
  sensitive   = true
  default     = "exporterpassword123"
}

variable "monitoring_exporter_image" {
  description = "MySQL Exporter Docker image"
  type        = string
  default     = "prom/mysqld-exporter:v0.15.1"
}

variable "monitoring_resources" {
  description = "Resource requests and limits for MySQL Exporter"
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
      cpu    = "50m"
      memory = "64Mi"
    }
    limits = {
      cpu    = "200m"
      memory = "128Mi"
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

variable "helm_timeout_operator" {
  description = "Timeout in seconds for Helm operator operations (usually faster)"
  type        = number
  default     = 300
}

