# ==============================================================================
# Consolidated Outputs: AWS Apache Airflow Hybrid Blueprint (V5 Complete)
# ==============================================================================

# ------------------------------------------------------------------------------
# Ingress & Networking
# ------------------------------------------------------------------------------
output "alb_dns_name" {
  description = "Public DNS name of the Application Load Balancer for accessing the Airflow Web UI"
  value       = module.alb.alb_dns_name
}

output "alb_zone_id" {
  description = "Canonical hosted zone ID of the Application Load Balancer"
  value       = module.alb.alb_zone_id
}

output "certificate_arn" {
  description = "ARN of the active TLS certificate applied to the HTTPS listener"
  value       = module.alb.certificate_arn
}

output "vpc_id" {
  description = "ID of the created Multi-AZ VPC"
  value       = module.vpc.vpc_id
}

output "public_subnet_ids" {
  description = "List of public subnet IDs across Availability Zones"
  value       = module.vpc.public_subnet_ids
}

output "private_subnet_ids" {
  description = "List of private subnet IDs across Availability Zones"
  value       = module.vpc.private_subnet_ids
}

output "nat_gateway_public_ip" {
  description = "Public Elastic IP allocated to the NAT Gateway"
  value       = module.vpc.nat_gateway_public_ip
}

output "s3_vpc_endpoint_id" {
  description = "ID of the zero-cost S3 Gateway VPC Endpoint"
  value       = module.vpc.s3_vpc_endpoint_id
}

# ------------------------------------------------------------------------------
# Security Groups
# ------------------------------------------------------------------------------
output "alb_security_group_id" {
  description = "Security group ID for Application Load Balancer (sg_alb)"
  value       = module.security_groups.alb_security_group_id
}

output "airflow_ec2_security_group_id" {
  description = "Security group ID for Airflow Core EC2 Webserver and Scheduler (sg_airflow_ec2)"
  value       = module.security_groups.airflow_ec2_security_group_id
}

output "airflow_workers_security_group_id" {
  description = "Security group ID for ephemeral ECS Fargate worker tasks (sg_airflow_workers)"
  value       = module.security_groups.airflow_workers_security_group_id
}

output "airflow_db_security_group_id" {
  description = "Security group ID for Airflow RDS PostgreSQL metadata database (sg_airflow_db)"
  value       = module.security_groups.airflow_db_security_group_id
}

output "clients_db_security_group_id" {
  description = "Security group ID for business target Clients Databases (sg_clients_db)"
  value       = module.security_groups.clients_db_security_group_id
}

# ------------------------------------------------------------------------------
# Identity & CI/CD
# ------------------------------------------------------------------------------
output "github_actions_role_arn" {
  description = "ARN of the IAM Role assumed by GitHub Actions via OIDC"
  value       = module.iam_oidc.github_actions_role_arn
}

output "ec2_instance_profile_name" {
  description = "Name of the IAM Instance Profile attached to Airflow Core EC2"
  value       = module.iam_oidc.ec2_instance_profile_name
}

output "ecs_task_execution_role_arn" {
  description = "ARN of the ECS Task Execution Role for Fargate workers"
  value       = module.iam_oidc.ecs_task_execution_role_arn
}

output "ecs_task_role_arn" {
  description = "ARN of the ECS Task Role for Fargate workers"
  value       = module.iam_oidc.ecs_task_role_arn
}

# ------------------------------------------------------------------------------
# Storage & Database
# ------------------------------------------------------------------------------
output "dags_bucket_name" {
  description = "Name of the S3 bucket housing Airflow DAG definitions"
  value       = module.s3_dags.bucket_id
}

output "dags_bucket_arn" {
  description = "ARN of the S3 bucket housing Airflow DAG definitions"
  value       = module.s3_dags.bucket_arn
}

output "rds_endpoint" {
  description = "Connection endpoint of the RDS PostgreSQL metadata database"
  value       = module.rds.db_instance_endpoint
}

output "rds_db_name" {
  description = "Database name of the Airflow metadata store"
  value       = module.rds.db_name
}

# ------------------------------------------------------------------------------
# Compute (EC2 Core & ECS Fargate)
# ------------------------------------------------------------------------------
output "ec2_instance_id" {
  description = "Instance ID of the Airflow Core EC2 instance"
  value       = module.ec2_airflow.instance_id
}

output "ec2_private_ip" {
  description = "Private IP address of the Airflow Core EC2 instance"
  value       = module.ec2_airflow.instance_private_ip
}

output "ecs_cluster_name" {
  description = "Name of the ECS Cluster running ephemeral Airflow workers"
  value       = module.ecs_fargate.cluster_name
}

output "ecs_cluster_arn" {
  description = "ARN of the ECS Cluster running ephemeral Airflow workers"
  value       = module.ecs_fargate.cluster_arn
}

output "ecr_repository_url" {
  description = "URL of the Amazon ECR repository for Airflow worker container images"
  value       = module.ecs_fargate.ecr_repository_url
}

output "worker_task_definition_arn" {
  description = "ARN of the base Airflow Worker ECS Task Definition"
  value       = module.ecs_fargate.task_definition_arn
}

output "worker_task_definition_family" {
  description = "Family of the base Airflow Worker ECS Task Definition"
  value       = module.ecs_fargate.task_definition_family
}
