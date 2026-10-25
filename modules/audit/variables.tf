variable "owner" {
  description = "Name prefix (shared account)."
  type        = string
}

variable "retention_mode" {
  description = "Object Lock mode: GOVERNANCE (bypass denied by bucket policy) or COMPLIANCE (irreversible)."
  type        = string
  default     = "GOVERNANCE"
  validation {
    condition     = contains(["COMPLIANCE", "GOVERNANCE"], var.retention_mode)
    error_message = "retention_mode must be COMPLIANCE or GOVERNANCE."
  }
}

variable "retention_days" {
  description = "Minimum retention for audit logs (HC-3: at least 365)."
  type        = number
  default     = 365
  validation {
    condition     = var.retention_days >= 365
    error_message = "HC-3 requires at least 365 days."
  }
}
