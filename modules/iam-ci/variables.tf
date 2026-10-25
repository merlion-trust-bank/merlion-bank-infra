variable "owner" {
  description = "Name prefix (shared account)."
  type        = string
}

variable "environment" {
  description = "Environment this CI role deploys."
  type        = string
  validation {
    condition     = contains(["staging", "prod"], var.environment)
    error_message = "environment must be staging or prod."
  }
}

variable "github_oidc_provider_arn" {
  description = "ARN of token.actions.githubusercontent.com in this account."
  type        = string
}

variable "github_subjects" {
  description = "Allowed OIDC 'sub' claims, e.g. repo:ORG/REPO:environment:staging"
  type        = list(string)
}

variable "state_bucket" {
  description = "Terraform remote state bucket."
  type        = string
}
