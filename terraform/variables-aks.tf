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





