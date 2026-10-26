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

module "eks" {
  source               = "../../modules/eks"
  owner                = var.owner
  environment          = local.environment
  subnet_ids           = module.network.private_subnet_ids
  secrets_kms_key_arn  = module.kms.key_arns["secrets"]
  logs_kms_key_arn     = module.kms.key_arns["logs"]
  admin_principal_arns = ["arn:aws:iam::255945442255:user/students/ce13/kealeee"]
}
