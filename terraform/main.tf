locals {
  name_prefix = "${var.project_name}-${var.environment}"
  merged_tags = merge(
    var.tags,
    {
      Project     = "aws-airflow-ecs-blueprint"
      ManagedBy   = "Terraform"
      Owner       = "Hilixops"
      Environment = var.environment
    }
  )
}

# ------------------------------------------------------------------------------
# 1. Network Layer (Multi-AZ VPC, Subnets, NAT GW, S3 Gateway Endpoint)
# ------------------------------------------------------------------------------
module "vpc" {
  source               = "./modules/vpc"
  name_prefix          = local.name_prefix
  vpc_cidr             = var.vpc_cidr
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs

  tags = local.merged_tags
}

# ------------------------------------------------------------------------------
# 2. Security Layer (Micro-Segmented Security Groups)
# ------------------------------------------------------------------------------
module "security_groups" {
  source                 = "./modules/security-groups"
  name_prefix            = local.name_prefix
  vpc_id                 = module.vpc.vpc_id
  airflow_webserver_port = var.airflow_webserver_port
  postgres_port          = var.postgres_port
  clients_db_port        = var.clients_db_port

  tags = local.merged_tags
}

# ------------------------------------------------------------------------------
# 3. Storage Layer (Private Versioned S3 Bucket for DAGs)
# ------------------------------------------------------------------------------
module "s3_dags" {
  source        = "./modules/s3-dags"
  name_prefix   = local.name_prefix
  bucket_name   = var.dags_bucket_name
  force_destroy = var.dags_bucket_force_destroy

  tags = local.merged_tags
}

# ------------------------------------------------------------------------------
# 4. Database Layer (Amazon RDS PostgreSQL Metadata Store)
# ------------------------------------------------------------------------------
module "rds" {
  source               = "./modules/rds"
  name_prefix          = local.name_prefix
  private_subnet_ids   = module.vpc.private_subnet_ids
  db_security_group_id = module.security_groups.airflow_db_security_group_id

  db_name                 = var.db_name
  db_username             = var.db_username
  db_password             = var.db_password
  instance_class          = var.db_instance_class
  allocated_storage       = var.db_allocated_storage
  max_allocated_storage   = var.db_max_allocated_storage
  multi_az                = var.db_multi_az
  port                    = var.postgres_port
  backup_retention_period = var.db_backup_retention_period
  deletion_protection     = var.db_deletion_protection
  skip_final_snapshot     = var.db_skip_final_snapshot

  tags = local.merged_tags
}

# ------------------------------------------------------------------------------
# 5. Container Registry & Ephemeral Compute Layer (ECS Fargate Workers)
# ------------------------------------------------------------------------------
module "ecs_fargate" {
  source              = "./modules/ecs-fargate"
  name_prefix         = local.name_prefix
  ecr_repository_name = var.ecr_repository_name
  log_retention_days  = var.log_retention_days
  worker_cpu          = var.worker_cpu
  worker_memory       = var.worker_memory

  execution_role_arn = module.iam_oidc.ecs_task_execution_role_arn
  task_role_arn      = module.iam_oidc.ecs_task_role_arn

  dags_bucket_name = module.s3_dags.bucket_id
  db_endpoint      = module.rds.db_instance_endpoint
  db_name          = module.rds.db_name
  db_username      = module.rds.db_username
  db_password      = var.db_password
  aws_region       = var.aws_region

  tags = local.merged_tags
}

# ------------------------------------------------------------------------------
# 6. Identity & Access Management (OIDC, EC2 Profile, ECS Roles)
# ------------------------------------------------------------------------------
module "iam_oidc" {
  source               = "./modules/iam-oidc"
  name_prefix          = local.name_prefix
  github_repo          = var.github_repo
  ecr_repository_arn   = module.ecs_fargate.ecr_repository_arn
  dags_bucket_arn      = module.s3_dags.bucket_arn
  create_oidc_provider = var.create_oidc_provider

  tags = local.merged_tags
}

# ------------------------------------------------------------------------------
# 7. Ingress & Routing Layer (ALB, Route 53, HTTPS/ACM)
# ------------------------------------------------------------------------------
module "alb" {
  source                 = "./modules/alb-route53"
  name_prefix            = local.name_prefix
  vpc_id                 = module.vpc.vpc_id
  public_subnet_ids      = module.vpc.public_subnet_ids
  alb_security_group_id  = module.security_groups.alb_security_group_id
  airflow_webserver_port = var.airflow_webserver_port
  health_check_path      = "/health"

  domain_name     = var.domain_name
  route53_zone_id = var.route53_zone_id
  certificate_arn = var.certificate_arn

  tags = local.merged_tags
}

# ------------------------------------------------------------------------------
# 8. Control Plane Compute Layer (Airflow Webserver & Scheduler on EC2)
# ------------------------------------------------------------------------------
module "ec2_airflow" {
  source                     = "./modules/ec2-airflow"
  name_prefix                = local.name_prefix
  instance_type              = var.ec2_instance_type
  ami_id                     = var.ec2_ami_id
  root_volume_size           = var.ec2_root_volume_size
  private_subnet_id          = module.vpc.private_subnet_ids[0]
  security_group_id          = module.security_groups.airflow_ec2_security_group_id
  iam_instance_profile_name  = module.iam_oidc.ec2_instance_profile_name
  target_group_arn           = module.alb.target_group_arn
  airflow_webserver_port     = var.airflow_webserver_port
  dags_bucket_name           = module.s3_dags.bucket_id
  db_endpoint                = module.rds.db_instance_endpoint
  db_name                    = module.rds.db_name
  db_username                = module.rds.db_username
  db_password                = var.db_password
  ecs_cluster_name           = module.ecs_fargate.cluster_name
  ecs_task_definition_family = module.ecs_fargate.task_definition_family
  private_subnet_ids         = module.vpc.private_subnet_ids
  worker_security_group_id   = module.security_groups.airflow_workers_security_group_id
  aws_region                 = var.aws_region

  tags = local.merged_tags
}
