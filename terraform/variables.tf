variable "subscription_id" {
  description = "Azure subscription ID"
  type        = string
}

variable "resource_group_name" {
  description = "Name of the Azure resource group (Note: Azure doesn't support renaming, so changing this will force cluster replacement)"
  type        = string
  default     = "k3s-cluster-rg"
}

variable "location" {
  description = "Azure region for resources"
  type        = string
  default     = "southeastasia"
}


variable "environment" {
  description = "Environment name (e.g., dev, staging, prod)"
  type        = string
  default     = "prod"
}

# AKS Configuration
variable "aks_cluster_name" {
  description = "Name of the AKS cluster"
  type        = string
  default     = "aks-cluster"
}

variable "aks_node_count" {
  description = "Number of nodes in the AKS node pool"
  type        = number
  default     = 1
}

variable "aks_vm_size" {
  description = "VM size for AKS nodes"
  type        = string
  default     = "Standard_D2s_v3"
}

variable "kubernetes_version" {
  description = "Kubernetes version for AKS cluster (leave empty to use latest)"
  type        = string
  default     = ""
}

# Additional Node Pool Configuration (D4 - 4 CPU)
variable "aks_d4_node_pool_enabled" {
  description = "Enable additional node pool with 4 CPU (D4 instance)"
  type        = bool
  default     = true
}

variable "aks_d4_node_pool_name" {
  description = "Name of the D4 node pool"
  type        = string
  default     = "d4pool"
}

variable "aks_d4_vm_size" {
  description = "VM size for D4 node pool (4 CPU)"
  type        = string
  default     = "Standard_D4s_v3"
}

variable "aks_d4_node_count" {
  description = "Number of nodes in the D4 node pool"
  type        = number
  default     = 1
}

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

# Ingress NGINX Configuration
variable "ingress_nginx_enabled" {
  description = "Enable NGINX Ingress Controller installation"
  type        = bool
  default     = true
}

variable "ingress_nginx_version" {
  description = "Version of NGINX Ingress Controller Helm chart"
  type        = string
  default     = "4.8.3"
}

# cert-manager Configuration
variable "cert_manager_enabled" {
  description = "Enable cert-manager installation"
  type        = bool
  default     = true
}

variable "cert_manager_version" {
  description = "Version of cert-manager Helm chart"
  type        = string
  default     = "v1.13.3"
}

# Grafana Configuration
variable "grafana_enabled" {
  description = "Enable Grafana deployment"
  type        = bool
  default     = true
}

variable "grafana_domain" {
  description = "Base domain for Grafana endpoint"
  type        = string
  default     = "terapeas.com"
}

variable "grafana_chart_version" {
  description = "Grafana Helm chart version"
  type        = string
  default     = "9.2.7"
}

variable "grafana_cluster_issuer_name" {
  description = "Name of the cert-manager ClusterIssuer to use for Grafana (default: letsencrypt-prod)"
  type        = string
  default     = "letsencrypt-prod"
}

variable "grafana_storage_class" {
  description = "Storage class for Grafana persistent volume (check available with: kubectl get storageclass)"
  type        = string
  default     = "managed-premium"
}

variable "grafana_storage_size" {
  description = "Size of the Grafana persistent volume"
  type        = string
  default     = "10Gi"
}

variable "grafana_admin_user" {
  description = "Grafana admin username"
  type        = string
  default     = "admin"
}

variable "grafana_admin_password" {
  description = "Grafana admin password (leave empty to auto-generate)"
  type        = string
  sensitive   = true
  default     = "nvROwPt9jwdpdreu3kNkZ48R5PfyWezU7PVuMxGs"
}

variable "grafana_loki_datasource_url" {
  description = "Loki datasource URL for Grafana"
  type        = string
  default     = "http://loki-gateway.observability.svc.cluster.local/"
}

variable "grafana_prometheus_datasource_url" {
  description = "Prometheus datasource URL for Grafana"
  type        = string
  default     = "http://prometheus.observability.svc.cluster.local:9090"
}

variable "grafana_enable_loki_datasource" {
  description = "Enable Loki datasource provisioning in Grafana"
  type        = bool
  default     = true
}

variable "grafana_enable_prometheus_datasource" {
  description = "Enable Prometheus datasource provisioning in Grafana"
  type        = bool
  default     = true
}

# Loki Configuration
variable "loki_enabled" {
  description = "Enable Loki deployment"
  type        = bool
  default     = true
}

variable "loki_namespace" {
  description = "Kubernetes namespace for Loki"
  type        = string
  default     = "observability"
}

variable "loki_chart_version" {
  description = "Loki Helm chart version"
  type        = string
  default     = "6.30.1"
}

variable "loki_storage_class" {
  description = "Storage class for Loki persistent volume"
  type        = string
  default     = "managed-premium"
}

variable "loki_storage_size" {
  description = "Size of the Loki persistent volume"
  type        = string
  default     = "3Gi"
}

variable "loki_retention_period" {
  description = "Loki log retention period (e.g., 72h for 3 days)"
  type        = string
  default     = "72h"
}

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

# Prometheus Configuration
variable "prometheus_enabled" {
  description = "Enable Prometheus deployment"
  type        = bool
  default     = true
}

variable "prometheus_namespace" {
  description = "Kubernetes namespace for Prometheus"
  type        = string
  default     = "observability"
}

variable "prometheus_chart_version" {
  description = "Prometheus Helm chart version (leave empty for latest)"
  type        = string
  default     = ""
}

variable "prometheus_storage_class" {
  description = "Storage class for Prometheus persistent volume"
  type        = string
  default     = "managed-premium"
}

variable "prometheus_storage_size" {
  description = "Size of the Prometheus persistent volume"
  type        = string
  default     = "10Gi"
}

variable "prometheus_retention_time" {
  description = "Prometheus data retention time (e.g., 7d)"
  type        = string
  default     = "7d"
}

variable "prometheus_enable_node_exporter" {
  description = "Enable node-exporter (included in Prometheus chart)"
  type        = bool
  default     = true
}

variable "prometheus_enable_kube_state_metrics" {
  description = "Enable kube-state-metrics (included in Prometheus chart)"
  type        = bool
  default     = true
}

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

# Helm Optimization Variables
variable "helm_wait_enabled" {
  description = "Enable wait for Helm releases to be ready. Set to false for faster applies on stable charts."
  type        = bool
  default     = true
}

variable "helm_wait_for_jobs_enabled" {
  description = "Enable wait for Helm jobs to complete. Set to false for faster applies on stable charts."
  type        = bool
  default     = true
}

variable "helm_timeout" {
  description = "Timeout in seconds for Helm operations"
  type        = number
  default     = 600
}

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

