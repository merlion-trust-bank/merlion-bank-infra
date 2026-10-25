terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.80"
    }
  }

  # Remote state: own key per environment, S3-native locking
  backend "s3" {
    bucket       = "kean-merlion-tfstate-255945442255"
    key          = "envs/staging/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project     = "merlion-trust-bank"
      Owner       = var.owner
      ManagedBy   = "terraform"
      Environment = local.environment
      Stack       = "envs/${local.environment}"
    }
  }
}
