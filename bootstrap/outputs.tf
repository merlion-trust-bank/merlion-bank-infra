output "region" {
  value = var.region
}

output "state_bucket" {
  description = "Backend bucket for envs/* (use_lockfile = true)."
  value       = aws_s3_bucket.tfstate.bucket
}

output "github_oidc_provider_arn" {
  description = "Trusted by the gha-* roles in INF-03."
  value = (var.create_github_oidc_provider
    ? aws_iam_openid_connect_provider.github[0].arn
  : data.aws_iam_openid_connect_provider.github[0].arn)
}

output "gha_staging_role_arn" {
  description = "Assumed by workflows in GitHub environment 'staging'."
  value       = module.gha_staging.role_arn
}

output "gha_prod_role_arn" {
  description = "Assumed by workflows in GitHub environment 'production' (after approval)."
  value       = module.gha_prod.role_arn
}

output "audit_bucket" {
  value = module.audit.audit_bucket
}

output "trail_arn" {
  value = module.audit.trail_arn
}
