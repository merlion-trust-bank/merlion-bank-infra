output "endpoints" {
  description = "Map of database => host (port 5432)."
  value       = { for k, db in aws_db_instance.this : k => db.address }
}

output "master_secret_arns" {
  description = "Map of database => Secrets Manager ARN holding the generated master password."
  value       = { for k, db in aws_db_instance.this : k => db.master_user_secret[0].secret_arn }
}

output "security_group_id" {
  value = aws_security_group.rds.id
}
