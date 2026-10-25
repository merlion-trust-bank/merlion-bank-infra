data "aws_caller_identity" "current" {}

locals {
  state_bucket = "${var.owner}-merlion-tfstate-${data.aws_caller_identity.current.account_id}"
}

# ---------- Terraform remote state (us-east-1) ----------
resource "aws_s3_bucket" "tfstate" {
  bucket = local.state_bucket

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_versioning" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "aws:kms"
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "tfstate" {
  bucket                  = aws_s3_bucket.tfstate.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_policy" "tfstate_tls_only" {
  bucket = aws_s3_bucket.tfstate.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "DenyInsecureTransport"
      Effect    = "Deny"
      Principal = "*"
      Action    = "s3:*"
      Resource  = [aws_s3_bucket.tfstate.arn, "${aws_s3_bucket.tfstate.arn}/*"]
      Condition = { Bool = { "aws:SecureTransport" = "false" } }
    }]
  })
  depends_on = [aws_s3_bucket_public_access_block.tfstate]
}

# ---------- GitHub Actions OIDC provider (one per account: reuse if it exists) ----------
resource "aws_iam_openid_connect_provider" "github" {
  count           = var.create_github_oidc_provider ? 1 : 0
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1", "1c58a3a8518e8759bf075b76b750d4f2df264fcd"]
}

data "aws_iam_openid_connect_provider" "github" {
  count = var.create_github_oidc_provider ? 0 : 1
  url   = "https://token.actions.githubusercontent.com"
}

# ---------- CI roles: one per environment (INF-03) ----------
locals {
  github_oidc_arn = (var.create_github_oidc_provider
    ? aws_iam_openid_connect_provider.github[0].arn
  : data.aws_iam_openid_connect_provider.github[0].arn)
}

module "gha_staging" {
  source                   = "../modules/iam-ci"
  owner                    = var.owner
  environment              = "staging"
  github_oidc_provider_arn = local.github_oidc_arn
  state_bucket             = aws_s3_bucket.tfstate.bucket
  github_subjects          = [for r in var.github_repos : "repo:${var.github_org}/${r}:environment:staging"]
}

module "gha_prod" {
  source                   = "../modules/iam-ci"
  owner                    = var.owner
  environment              = "prod"
  github_oidc_provider_arn = local.github_oidc_arn
  state_bucket             = aws_s3_bucket.tfstate.bucket
  github_subjects          = [for r in var.github_repos : "repo:${var.github_org}/${r}:environment:production"]
}
