terraform {
  required_version = ">= 1.10"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.80"
    }
  }
}

variable "owner" {
  type = string
}

variable "services" {
  description = "One repository per independently deployable service."
  type        = list(string)
  default     = ["frontend", "userservice", "contacts", "ledgerwriter", "balancereader", "transactionhistory", "loadgenerator"]
}

variable "keep_last_images" {
  type    = number
  default = 20
}

resource "aws_ecr_repository" "this" {
  for_each             = toset(var.services)
  name                 = "${var.owner}-merlion/${each.key}"
  image_tag_mutability = "IMMUTABLE"
  force_delete         = true # lab account is wiped nightly

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }
}

resource "aws_ecr_lifecycle_policy" "this" {
  for_each   = aws_ecr_repository.this
  repository = each.value.name
  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep the last ${var.keep_last_images} images"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = var.keep_last_images
      }
      action = { type = "expire" }
    }]
  })
}

output "repository_urls" {
  description = "Map of service => repository URL."
  value       = { for k, r in aws_ecr_repository.this : k => r.repository_url }
}
