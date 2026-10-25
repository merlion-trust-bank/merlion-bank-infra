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

variable "github_org" {
  description = "GitHub organisation that may assume the CI roles."
  type        = string
  default     = "merlion-trust-bank"
}

variable "github_repos" {
  description = "Repos whose workflows may assume the CI roles."
  type        = list(string)
  default     = ["merlion-bank-infra", "merlion-bank-app"]
}
