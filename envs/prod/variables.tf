variable "region" {
  description = "Only approved region for this project."
  type        = string
  default     = "us-east-1"
  validation {
    condition     = var.region == "us-east-1"
    error_message = "Only us-east-1 is approved for this project (ADR-006)."
  }
}

variable "owner" {
  description = "Name prefix (shared account)."
  type        = string
  default     = "kean"
}
