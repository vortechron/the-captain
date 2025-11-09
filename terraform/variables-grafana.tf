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

