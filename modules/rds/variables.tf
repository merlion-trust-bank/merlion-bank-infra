variable "owner" {
  type = string
}

variable "environment" {
  type = string
  validation {
    condition     = contains(["staging", "prod"], var.environment)
    error_message = "environment must be staging or prod."
  }
}

variable "vpc_id" {
  type = string
}

variable "db_subnet_ids" {
  description = "Isolated DB subnets (no internet route), 2 AZs."
  type        = list(string)
}

variable "allowed_security_group_ids" {
  description = "Only these SGs may connect on 5432 (the EKS cluster SG)."
  type        = list(string)
}

variable "rds_kms_key_arn" {
  description = "CMK for storage encryption."
  type        = string
}

variable "secrets_kms_key_arn" {
  description = "CMK for the AWS-managed master password secret."
  type        = string
}

variable "databases" {
  description = "One RDS instance per app database: key => { db_name, username }."
  type = map(object({
    db_name  = string
    username = string
  }))
  default = {
    accounts = { db_name = "accountsdb", username = "accounts_admin" }
    ledger   = { db_name = "ledgerdb", username = "ledger_admin" }
  }
}

variable "engine_version" {
  type    = string
  default = "16"
}

variable "instance_class" {
  type    = string
  default = "db.t4g.micro"
}

variable "multi_az" {
  type    = bool
  default = false
}

variable "backup_retention_days" {
  type    = number
  default = 7
}
