locals {
  environment  = "staging"
  name         = "${var.owner}-${local.environment}"
  cluster_name = "${local.name}-eks"
}

module "kms" {
  source      = "../../modules/kms"
  owner       = var.owner
  environment = local.environment
}

module "network" {
  # Shared course VPC (VPC quota is full in this account); looked up, not created
  source   = "../../modules/network-lookup"
  vpc_name = "sctp-vpc-ce13"
}
