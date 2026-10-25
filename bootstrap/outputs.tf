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
