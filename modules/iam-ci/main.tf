data "aws_caller_identity" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
  role_name  = "${var.owner}-gha-${var.environment}"
  prefix     = "${var.owner}-${var.environment}"
  other_env  = var.environment == "prod" ? "staging" : "prod"
}

# ---------- WHO may assume this role ----------
data "aws_iam_policy_document" "trust" {
  statement {
    sid     = "GitHubOIDC"
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [var.github_oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    # Only our repos, only from the matching GitHub environment
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = var.github_subjects
    }
  }
}

resource "aws_iam_role" "this" {
  name                 = local.role_name
  description          = "GitHub Actions deploy role for ${var.environment} (OIDC, no static keys)"
  assume_role_policy   = data.aws_iam_policy_document.trust.json
  max_session_duration = 3600

  tags = {
    Environment = var.environment
  }
}

# ---------- WHAT it may do ----------
# Broad infra rights for EC2/EKS/RDS/S3/etc. (excludes IAM and Organizations)
resource "aws_iam_role_policy_attachment" "power_user" {
  role       = aws_iam_role.this.name
  policy_arn = "arn:aws:iam::aws:policy/PowerUserAccess"
}

data "aws_iam_policy_document" "scoped" {
  # Terraform state: own environment only
  statement {
    sid       = "StateObjectsOwnEnv"
    actions   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
    resources = ["arn:aws:s3:::${var.state_bucket}/envs/${var.environment}/*"]
  }

  statement {
    sid       = "StateListOwnEnv"
    actions   = ["s3:ListBucket"]
    resources = ["arn:aws:s3:::${var.state_bucket}"]
    condition {
      test     = "StringLike"
      variable = "s3:prefix"
      values   = ["envs/${var.environment}/*"]
    }
  }

  # IAM: only roles/policies named for this environment (EKS, IRSA, node roles)
  statement {
    sid     = "IamOwnEnvOnly"
    actions = ["iam:*"]
    resources = [
      "arn:aws:iam::${local.account_id}:role/${local.prefix}-*",
      "arn:aws:iam::${local.account_id}:policy/${local.prefix}-*",
      "arn:aws:iam::${local.account_id}:instance-profile/${local.prefix}-*",
      "arn:aws:iam::${local.account_id}:oidc-provider/oidc.eks.us-east-1.amazonaws.com/*",
    ]
  }

  statement {
    sid       = "IamReadAndServiceLinked"
    actions   = ["iam:Get*", "iam:List*", "iam:CreateServiceLinkedRole"]
    resources = ["*"]
  }

  # Hard separation: never touch the other environment
  statement {
    sid       = "DenyOtherEnvironmentResources"
    effect    = "Deny"
    actions   = ["*"]
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "aws:ResourceTag/Environment"
      values   = [local.other_env]
    }
  }

  statement {
    sid     = "DenyOtherEnvironmentAndBootstrapState"
    effect  = "Deny"
    actions = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
    resources = [
      "arn:aws:s3:::${var.state_bucket}/envs/${local.other_env}/*",
      "arn:aws:s3:::${var.state_bucket}/bootstrap/*",
    ]
  }
}

resource "aws_iam_role_policy" "scoped" {
  name   = "${local.role_name}-scoped"
  role   = aws_iam_role.this.id
  policy = data.aws_iam_policy_document.scoped.json
}

# ---------- Region guardrail (INF-11): deny everything outside approved regions ----------
data "aws_iam_policy_document" "region_guardrail" {
  statement {
    sid    = "DenyOutsideApprovedRegions"
    effect = "Deny"
    # Global services have no region (or report us-east-1); exempt so they keep working
    not_actions = [
      "iam:*", "sts:*", "organizations:*", "account:*", "support:*",
      "budgets:*", "ce:*", "cur:*", "health:*", "pricing:*", "trustedadvisor:*",
      "cloudfront:*", "route53:*", "route53domains:*", "globalaccelerator:*",
      "waf:*", "shield:*",
    ]
    resources = ["*"]
    condition {
      test     = "StringNotEquals"
      variable = "aws:RequestedRegion"
      values   = var.allowed_regions
    }
  }
}

resource "aws_iam_role_policy" "region_guardrail" {
  name   = "${local.role_name}-region-guardrail"
  role   = aws_iam_role.this.id
  policy = data.aws_iam_policy_document.region_guardrail.json
}
