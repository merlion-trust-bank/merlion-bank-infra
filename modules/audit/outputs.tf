output "audit_bucket" {
  description = "Object Lock bucket: cloudtrail/, deploy-records/ (APP-11), eks-audit/."
  value       = aws_s3_bucket.audit.bucket
}

output "audit_kms_key_arn" {
  value = aws_kms_key.audit.arn
}

output "trail_arn" {
  value = aws_cloudtrail.this.arn
}
