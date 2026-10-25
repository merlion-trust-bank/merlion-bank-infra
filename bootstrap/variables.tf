variable "region" {
  description = "Only approved region for this project."
  type        = string
  default     = "us-east-1"

  validation {
    condition     = var.region == "us-east-1"
    error_message = "Only us-east-1 is approved for this project (instructor directive, ADR-006)."
  }
}

variable "owner" {
  description = "Name prefix; keeps resources unique in the shared course AWS account."
  type        = string
  default     = "kean"
}

variable "create_github_oidc_provider" {
  description = "false = reuse the account's existing token.actions.githubusercontent.com provider (one per account)."
  type        = bool
  default     = false
}
