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





