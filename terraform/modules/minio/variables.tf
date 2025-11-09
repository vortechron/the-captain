variable "storage_class" {
  description = "Storage class for MinIO persistent volume"
  type        = string
  default     = "managed-premium"
}

variable "storage_size" {
  description = "Size of the persistent volume"
  type        = string
  default     = "20Gi"
}

variable "domain" {
  description = "Base domain for MinIO endpoints"
  type        = string
  default     = "terapeas.com"
}

variable "minio_root_user" {
  description = "MinIO root username"
  type        = string
  sensitive   = true
  default     = "minioadmin"
}

variable "minio_root_password" {
  description = "MinIO root password"
  type        = string
  sensitive   = true
  default     = "Mpft0qBAEX2yIFXCqe/Ez5kAXZ89cabLEzI90jMtCRg="
}

variable "cert_manager_email" {
  description = "Email address for Let's Encrypt certificate"
  type        = string
  default     = "sayaamiruladli@gmail.com"
}

variable "cluster_issuer_name" {
  description = "Name of the cert-manager ClusterIssuer to use (leave empty to create one)"
  type        = string
  default     = "letsencrypt-prod"
}

variable "create_cluster_issuer" {
  description = "Whether to create a ClusterIssuer resource (set to false if ClusterIssuer already exists)"
  type        = bool
  default     = true
}

variable "namespace" {
  description = "Kubernetes namespace for MinIO"
  type        = string
  default     = "minio"
}

variable "minio_image" {
  description = "MinIO container image"
  type        = string
  default     = "minio/minio:latest"
}

variable "replicas" {
  description = "Number of MinIO replicas"
  type        = number
  default     = 1
}

variable "resources" {
  description = "Resource requests and limits for MinIO container"
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
      memory = "1Gi"
    }
  }
}

