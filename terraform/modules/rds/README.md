# RDS PostgreSQL Module (`modules/rds`)

## Overview

This module provisions an Amazon RDS PostgreSQL database dedicated to the **Apache Airflow Metadata Database**. It is deployed into a Multi-AZ DB Subnet Group across private subnets with no public internet ingress, encrypted storage (`gp3`), and automated backup policies.

### Architecture Highlights
- **Isolated Network Tier:** Deployed into private subnets; `publicly_accessible` is strictly set to `false`.
- **Micro-Segmented Access:** Bound to `sg_airflow_db`, accepting connections on port `5432` only from the Airflow EC2 Core instance (Webserver/Scheduler) and ephemeral Airflow ECS Fargate workers.
- **Storage Autoscaling:** Provisions `gp3` encrypted storage with configurable initial capacity (`allocated_storage`) and elastic upper bounds (`max_allocated_storage`).
- **UTF-8 Parameter Group:** Attaches a custom DB parameter group guaranteeing `UTF8` client encoding as required by Apache Airflow.

## Usage

```hcl
module "rds" {
  source = "./modules/rds"

  name_prefix          = "airflow-production"
  private_subnet_ids   = module.vpc.private_subnet_ids
  db_security_group_id = module.security_groups.airflow_db_security_group_id

  db_name             = "airflow"
  db_username         = "airflow_admin"
  db_password         = var.db_password
  instance_class      = "db.t4g.small"
  allocated_storage   = 20
  multi_az            = true
  deletion_protection = true

  tags = {
    Project     = "aws-airflow-ecs-blueprint"
    Environment = "production"
    ManagedBy   = "Terraform"
    Owner       = "Hilixops"
  }
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| `name_prefix` | Prefix used for naming all RDS resources | `string` | n/a | yes |
| `private_subnet_ids` | List of private subnet IDs for DB Subnet Group (minimum 2) | `list(string)` | n/a | yes |
| `db_security_group_id` | Security group ID attached to RDS | `string` | n/a | yes |
| `db_name` | Database name for the Airflow metadata store | `string` | `"airflow"` | no |
| `db_username` | Master username for PostgreSQL | `string` | `"airflow_admin"` | no |
| `db_password` | Master password for PostgreSQL (min 8 chars) | `string` | n/a | yes |
| `engine_version` | PostgreSQL engine version | `string` | `"15.7"` | no |
| `parameter_group_family` | DB parameter group family | `string` | `"postgres15"` | no |
| `instance_class` | RDS instance class | `string` | `"db.t4g.small"` | no |
| `allocated_storage` | Initial storage in GiB | `number` | `20` | no |
| `max_allocated_storage` | Maximum storage limit in GiB for autoscaling | `number` | `100` | no |
| `multi_az` | Deploy across multiple AZs for HA failover | `bool` | `false` | no |
| `port` | TCP port for PostgreSQL | `number` | `5432` | no |
| `backup_retention_period` | Number of days to retain automated backups | `number` | `7` | no |
| `deletion_protection` | Enable deletion protection | `bool` | `false` | no |
| `skip_final_snapshot` | Skip snapshot before deletion | `bool` | `true` | no |
| `tags` | Resource tags to merge | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| `db_instance_id` | The RDS instance identifier |
| `db_instance_arn` | The ARN of the RDS instance |
| `db_instance_endpoint` | The connection endpoint in `address:port` format |
| `db_instance_address` | The hostname address of the RDS PostgreSQL instance |
| `db_instance_port` | The database port on which the instance accepts connections |
| `db_name` | The database name of the Airflow metadata store |
| `db_username` | The master username for the database |
| `db_subnet_group_name` | The name of the DB subnet group |
| `db_subnet_group_id` | The ID of the DB subnet group |
