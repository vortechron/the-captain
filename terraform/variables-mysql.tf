# MySQL Configuration
variable "mysql_enabled" {
  description = "Enable MySQL (Percona XtraDB Cluster) deployment"
  type        = bool
  default     = true
}

variable "mysql_namespace" {
  description = "Kubernetes namespace for MySQL"
  type        = string
  default     = "db"
}

variable "mysql_cluster_name" {
  description = "Name of the Percona XtraDB Cluster"
  type        = string
  default     = "cluster1"
}

variable "mysql_storage_class" {
  description = "Storage class for MySQL persistent volumes"
  type        = string
  default     = "managed-premium"
}

variable "mysql_storage_size" {
  description = "Size of the MySQL persistent volume per node"
  type        = string
  default     = "20Gi"
}

variable "mysql_pxc_size" {
  description = "Number of MySQL nodes in the cluster"
  type        = number
  default     = 1
}

variable "mysql_haproxy_size" {
  description = "Number of HAProxy replicas"
  type        = number
  default     = 1
}

variable "mysql_backup_enabled" {
  description = "Enable automated backups to MinIO"
  type        = bool
  default     = true
}

variable "mysql_backup_schedule" {
  description = "Cron schedule for daily backups"
  type        = string
  default     = "0 2 * * *" # 2 AM UTC daily
}

variable "mysql_backup_retention_days" {
  description = "Number of days to keep backups"
  type        = number
  default     = 7
}

variable "mysql_backup_resources" {
  description = "Resource requests and limits for MySQL backup jobs"
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

variable "mysql_backup_timeout_seconds" {
  description = "Timeout in seconds for MySQL backup operations"
  type        = number
  default     = 7200 # 2 hours (increased to handle Galera connection timeouts)
}

variable "mysql_minio_endpoint_url" {
  description = "MinIO S3 endpoint URL for MySQL backups"
  type        = string
  default     = "https://minio.aks.terapeas.com"
}

variable "mysql_minio_bucket" {
  description = "MinIO bucket name for MySQL backups"
  type        = string
  default     = "db-backup"
}

variable "mysql_minio_region" {
  description = "MinIO region for MySQL backups"
  type        = string
  default     = "us-east-1"
}

variable "mysql_minio_access_key_id" {
  description = "MinIO access key ID for MySQL backups"
  type        = string
  sensitive   = true
  default     = "minioadmin"
}

variable "mysql_minio_secret_access_key" {
  description = "MinIO secret access key for MySQL backups"
  type        = string
  sensitive   = true
  default     = "Mpft0qBAEX2yIFXCqe/Ez5kAXZ89cabLEzI90jMtCRg="
}

variable "mysql_root_password" {
  description = "MySQL root password (leave empty to auto-generate)"
  type        = string
  sensitive   = true
  default     = "jgab3IiennmI]OqS"
}

variable "mysql_monitoring_enabled" {
  description = "Enable MySQL monitoring with Prometheus exporter"
  type        = bool
  default     = true
}

variable "mysql_monitoring_user" {
  description = "MySQL user for monitoring (exporter)"
  type        = string
  default     = "exporter"
}

variable "mysql_monitoring_password" {
  description = "Password for MySQL monitoring user"
  type        = string
  sensitive   = true
  default     = "exporterpassword123"
}

variable "mysql_pxc_resources" {
  description = "Resource requests and limits for MySQL PXC pods"
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
      cpu    = "1000m"
      memory = "2Gi"
    }
  }
}

variable "mysql_haproxy_resources" {
  description = "Resource requests and limits for MySQL HAProxy pods"
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





