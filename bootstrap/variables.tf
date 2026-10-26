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

variable "audit_retention_mode" {
  description = "Object Lock mode for audit logs. GOVERNANCE (instructor advice); bypass denied by bucket policy."
  type        = string
  default     = "GOVERNANCE"
}

variable "github_org_id" {
  description = "Numeric GitHub org ID (used by immutable OIDC subject claims)."
  type        = number
  default     = 337367504
}

variable "github_repo_ids" {
  description = "Numeric GitHub repo IDs (used by immutable OIDC subject claims)."
  type        = map(number)
  default = {
    "merlion-bank-infra" = 1403279696
    "merlion-bank-app"   = 1403279963
  }
}
