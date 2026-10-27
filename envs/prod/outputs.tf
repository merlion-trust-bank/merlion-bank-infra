output "environment" {
  value = local.environment
}

output "vpc_id" {
  value = module.network.vpc_id
}

output "private_subnet_ids" {
  value = module.network.private_subnet_ids
}

output "db_subnet_ids" {
  value = module.network.db_subnet_ids
}

output "kms_key_arns" {
  value = module.kms.key_arns
}

output "eks_cluster_name" {
  value = module.eks.cluster_name
}

output "db_endpoints" {
  value = module.rds.endpoints
}

output "db_master_secret_arns" {
  value = module.rds.master_secret_arns
}
