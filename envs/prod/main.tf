locals {
  environment  = "prod"
  name         = "${var.owner}-${local.environment}"
  cluster_name = "${local.name}-eks"
}

module "kms" {
  source      = "../../modules/kms"
  owner       = var.owner
  environment = local.environment
}

module "network" {
  source                     = "../../modules/network"
  owner                      = var.owner
  environment                = local.environment
  vpc_cidr                   = "10.30.0.0/16"
  single_nat_gateway         = false
  enable_interface_endpoints = true
  eks_cluster_name           = local.cluster_name
}
