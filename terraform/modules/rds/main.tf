# ==============================================================================
# RDS PostgreSQL Module: Airflow Metadata Database
# Isolated in private subnets, encrypted at rest, Multi-AZ DB subnet group.
# ==============================================================================

resource "aws_db_subnet_group" "airflow" {
  name_prefix = "${var.name_prefix}-db-subnets-"
  description = "Multi-AZ database subnet group for Airflow metadata PostgreSQL"
  subnet_ids  = var.private_subnet_ids

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-db-subnet-group"
    }
  )

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_db_parameter_group" "airflow" {
  name_prefix = "${var.name_prefix}-pg-"
  family      = var.parameter_group_family
  description = "Custom parameter group for Airflow metadata PostgreSQL database"

  parameter {
    name  = "client_encoding"
    value = "UTF8"
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-db-parameter-group"
    }
  )

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_db_instance" "airflow" {
  identifier_prefix     = "${var.name_prefix}-rds-"
  engine                = "postgres"
  engine_version        = var.engine_version
  instance_class        = var.instance_class
  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.max_allocated_storage
  storage_type          = "gp3"
  storage_encrypted     = true

  db_name  = var.db_name
  username = var.db_username
  password = var.db_password
  port     = var.port

  multi_az               = var.multi_az
  publicly_accessible    = false
  vpc_security_group_ids = [var.db_security_group_id]
  db_subnet_group_name   = aws_db_subnet_group.airflow.name
  parameter_group_name   = aws_db_parameter_group.airflow.name

  backup_retention_period    = var.backup_retention_period
  deletion_protection        = var.deletion_protection
  skip_final_snapshot        = var.skip_final_snapshot
  final_snapshot_identifier  = var.skip_final_snapshot ? null : "${var.name_prefix}-rds-final-snapshot"
  copy_tags_to_snapshot      = true
  auto_minor_version_upgrade = true

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-airflow-db"
      Role = "MetadataDatabase"
    }
  )
}
