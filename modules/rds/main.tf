locals {
  prefix = "${var.owner}-${var.environment}"
}

resource "aws_db_subnet_group" "this" {
  name        = "${local.prefix}-db"
  description = "Isolated DB subnets for ${local.prefix}"
  subnet_ids  = var.db_subnet_ids
}

# Only the EKS cluster may reach PostgreSQL
resource "aws_security_group" "rds" {
  name        = "${local.prefix}-rds"
  description = "PostgreSQL from ${local.prefix} EKS only"
  vpc_id      = var.vpc_id
  tags        = { Name = "${local.prefix}-rds" }
}

resource "aws_vpc_security_group_ingress_rule" "from_eks" {
  count                        = length(var.allowed_security_group_ids)
  security_group_id            = aws_security_group.rds.id
  referenced_security_group_id = var.allowed_security_group_ids[count.index]
  ip_protocol                  = "tcp"
  from_port                    = 5432
  to_port                      = 5432
  description                  = "PostgreSQL from EKS"
}

# Enforce TLS for every connection
resource "aws_db_parameter_group" "this" {
  name        = "${local.prefix}-pg${var.engine_version}"
  family      = "postgres${var.engine_version}"
  description = "TLS enforced for ${local.prefix}"

  parameter {
    name  = "rds.force_ssl"
    value = "1"
  }
}

resource "aws_db_instance" "this" {
  for_each = var.databases

  identifier     = "${local.prefix}-${each.key}-db"
  engine         = "postgres"
  engine_version = var.engine_version
  instance_class = var.instance_class

  db_name  = each.value.db_name
  username = each.value.username
  # AWS generates the password and keeps it in Secrets Manager (never in code or state)
  manage_master_user_password   = true
  master_user_secret_kms_key_id = var.secrets_kms_key_arn

  allocated_storage = 20
  storage_type      = "gp3"
  storage_encrypted = true
  kms_key_id        = var.rds_kms_key_arn

  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  parameter_group_name   = aws_db_parameter_group.this.name
  publicly_accessible    = false
  multi_az               = var.multi_az

  backup_retention_period = var.backup_retention_days
  copy_tags_to_snapshot   = true

  # Lab account is wiped nightly: allow clean destroy
  skip_final_snapshot = true
  deletion_protection = false

  auto_minor_version_upgrade = true
  apply_immediately          = true

  tags = { Name = "${local.prefix}-${each.key}-db", Database = each.key }
}
