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





