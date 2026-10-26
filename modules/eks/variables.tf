variable "owner" {
  description = "Name prefix (shared account)."
  type        = string
}

variable "environment" {
  description = "staging or prod."
  type        = string
  validation {
    condition     = contains(["staging", "prod"], var.environment)
    error_message = "environment must be staging or prod."
  }
}

variable "subnet_ids" {
  description = "Private subnets (2 AZs) for the control plane ENIs and nodes."
  type        = list(string)
}

variable "kubernetes_version" {
  description = "EKS version; null = current EKS default."
  type        = string
  default     = null
}

variable "secrets_kms_key_arn" {
  description = "CMK for Kubernetes secrets envelope encryption."
  type        = string
}

variable "logs_kms_key_arn" {
  description = "CMK for the control-plane log group."
  type        = string
}

variable "log_retention_days" {
  description = "Control-plane (audit) log retention."
  type        = number
  default     = 365
}

variable "admin_principal_arns" {
  description = "Extra IAM principals given cluster admin (e.g. the engineer's IAM user)."
  type        = list(string)
  default     = []
}

variable "node_instance_types" {
  type    = list(string)
  default = ["t3.medium"]
}

variable "node_desired_size" {
  type    = number
  default = 2
}

variable "node_min_size" {
  type    = number
  default = 1
}

variable "node_max_size" {
  type    = number
  default = 3
}
