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

variable "purposes" {
  description = "One CMK per data type."
  type        = set(string)
  default     = ["rds", "s3", "logs", "secrets"]
}

variable "deletion_window_in_days" {
  description = "Waiting period before a scheduled key deletion completes (7-30)."
  type        = number
  default     = 7
}
