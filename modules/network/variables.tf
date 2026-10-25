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

variable "vpc_cidr" {
  description = "VPC CIDR, e.g. 10.20.0.0/16 (staging), 10.30.0.0/16 (prod)."
  type        = string
}

variable "azs" {
  description = "Exactly two AZs in us-east-1."
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
  validation {
    condition     = length(var.azs) == 2
    error_message = "This design uses exactly 2 AZs."
  }
}

variable "single_nat_gateway" {
  description = "true = 1 NAT (cheaper, staging); false = 1 NAT per AZ (resilient, prod)."
  type        = bool
  default     = true
}

variable "enable_interface_endpoints" {
  description = "Create interface endpoints (ECR, Secrets Manager, Logs, STS). ~USD 7/month each per AZ."
  type        = bool
  default     = false
}

variable "eks_cluster_name" {
  description = "Used for subnet discovery tags by the AWS Load Balancer Controller."
  type        = string
}
