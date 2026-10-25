data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
  region     = data.aws_region.current.name
}

data "aws_iam_policy_document" "key" {
  for_each = var.purposes

  # Account root delegates key access to IAM policies (standard AWS pattern)
  statement {
    sid       = "EnableIAMPolicies"
    actions   = ["kms:*"]
    resources = ["*"]
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${local.account_id}:root"]
    }
  }

  # Only the logs key: let CloudWatch Logs encrypt our log groups (e.g. EKS audit logs)
  dynamic "statement" {
    for_each = each.key == "logs" ? [1] : []
    content {
      sid = "AllowCloudWatchLogs"
      actions = [
        "kms:Encrypt*", "kms:Decrypt*", "kms:ReEncrypt*",
        "kms:GenerateDataKey*", "kms:Describe*",
      ]
      resources = ["*"]
      principals {
        type        = "Service"
        identifiers = ["logs.${local.region}.amazonaws.com"]
      }
      condition {
        test     = "ArnLike"
        variable = "kms:EncryptionContext:aws:logs:arn"
        values   = ["arn:aws:logs:${local.region}:${local.account_id}:log-group:*"]
      }
    }
  }
}

resource "aws_kms_key" "this" {
  for_each = var.purposes

  description             = "${var.owner}-${var.environment} CMK for ${each.key}"
  enable_key_rotation     = true
  deletion_window_in_days = var.deletion_window_in_days
  policy                  = data.aws_iam_policy_document.key[each.key].json

  tags = {
    Environment = var.environment
    Purpose     = each.key
  }
}

resource "aws_kms_alias" "this" {
  for_each = var.purposes

  name          = "alias/${var.owner}-${var.environment}-${each.key}"
  target_key_id = aws_kms_key.this[each.key].key_id
}
