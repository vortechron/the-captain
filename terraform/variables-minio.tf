# MinIO Configuration
variable "minio_enabled" {
  description = "Enable MinIO deployment"
  type        = bool
  default     = true
}

variable "minio_storage_class" {
  description = "Storage class for MinIO persistent volume (check available with: kubectl get storageclass)"
  type        = string
  default     = "managed-premium"
}

variable "minio_storage_size" {
  description = "Size of the MinIO persistent volume"
  type        = string
  default     = "20Gi"
}

variable "minio_domain" {
  description = "Base domain for MinIO endpoints"
  type        = string
  default     = "terapeas.com"
}

variable "minio_root_user" {
  description = "MinIO root username"
  type        = string
  sensitive   = false
  default     = "minioadmin"
}

variable "minio_root_password" {
  description = "MinIO root password"
  type        = string
  sensitive   = true
  default     = "Mpft0qBAEX2yIFXCqe/Ez5kAXZ89cabLEzI90jMtCRg="
}

variable "minio_cert_manager_email" {
  description = "Email address for Let's Encrypt certificate (only used if creating ClusterIssuer)"
  type        = string
  default     = "sayaamiruladli@gmail.com"
}

variable "minio_cluster_issuer_name" {
  description = "Name of the cert-manager ClusterIssuer to use (default: letsencrypt-prod)"
  type        = string
  default     = "letsencrypt-prod"
}

variable "minio_create_cluster_issuer" {
  description = "Whether to create a ClusterIssuer (set to false if ClusterIssuer already exists)"
  type        = bool
  default     = false
}

variable "minio_chart_version" {
  description = "MinIO Helm chart version (leave empty for latest)"
  type        = string
  default     = ""
}





