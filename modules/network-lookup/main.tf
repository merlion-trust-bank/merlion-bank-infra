terraform {
  required_version = ">= 1.10"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.80"
    }
  }
}

variable "vpc_name" {
  description = "Name tag of the shared course VPC (provided by the course, not managed here)."
  type        = string
  default     = "sctp-vpc-ce13"
}

# Look up (not create) the shared VPC and its three subnet tiers by Name tag
data "aws_vpc" "this" {
  filter {
    name   = "tag:Name"
    values = [var.vpc_name]
  }
}

data "aws_subnets" "tier" {
  for_each = toset(["public", "private", "db"])
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.this.id]
  }
  filter {
    name   = "tag:Name"
    values = ["${var.vpc_name}-${each.key}-*"]
  }
}

output "vpc_id" {
  value = data.aws_vpc.this.id
}

output "vpc_cidr" {
  value = data.aws_vpc.this.cidr_block
}

output "public_subnet_ids" {
  value = sort(data.aws_subnets.tier["public"].ids)
}

output "private_subnet_ids" {
  description = "EKS nodes and pods (egress via the course NAT gateway)."
  value       = sort(data.aws_subnets.tier["private"].ids)
}

output "db_subnet_ids" {
  description = "Isolated: no internet route. For the RDS subnet group."
  value       = sort(data.aws_subnets.tier["db"].ids)
}
