# ECS Fargate Module (`modules/ecs-fargate`)

## Overview

This module provisions the elastic, serverless compute infrastructure for **Apache Airflow Tasks** using `AwsEcsExecutor` on AWS Fargate.

### Architecture Highlights
- **Zero-Idle-Cost Task Execution ($0.00 at rest):** Rather than maintaining persistent worker instances or Celery broker clusters (Redis/RabbitMQ), tasks are launched on-demand via `ecs:RunTask` and automatically destroyed upon completion.
- **Container Registry:** Dedicated Amazon ECR repository with AES-256 encryption and automated image vulnerability scanning on push.
- **Container Insights:** Enabled at the ECS Cluster level for detailed telemetry and CPU/memory utilization tracking.
- **Task Definition:** Base Fargate task definition running custom worker images, configured with `awslogs` driver routing output directly to Amazon CloudWatch Logs.
- **Dynamic DAG Fetching:** The worker container entrypoint synchronizes DAG definitions from the S3 DAGs bucket before executing `airflow tasks run`.

## Usage

```hcl
module "ecs_fargate" {
  source = "./modules/ecs-fargate"

  name_prefix         = "airflow-production"
  ecr_repository_name = "airflow-worker"
  log_retention_days  = 30
  worker_cpu          = 512
  worker_memory       = 1024

  execution_role_arn  = module.iam_oidc.ecs_task_execution_role_arn
  task_role_arn       = module.iam_oidc.ecs_task_role_arn

  dags_bucket_name    = module.s3_dags.bucket_id
  db_endpoint         = module.rds.db_instance_endpoint
  db_name             = module.rds.db_name
  db_username         = module.rds.db_username
  db_password         = var.db_password
  aws_region          = var.aws_region

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
| `name_prefix` | Prefix used for naming ECS resources | `string` | n/a | yes |
| `ecr_repository_name` | Name for the ECR repository housing Airflow worker images | `string` | `"airflow-worker"` | no |
| `log_retention_days` | Retention period in days for CloudWatch log events | `number` | `30` | no |
| `worker_cpu` | CPU units allocated for Fargate tasks | `number` | `512` | no |
| `worker_memory` | Memory (in MiB) allocated for Fargate tasks | `number` | `1024` | no |
| `execution_role_arn` | ARN of the ECS Task Execution Role | `string` | n/a | yes |
| `task_role_arn` | ARN of the ECS Task Role | `string` | n/a | yes |
| `container_image` | Custom container image URI (optional, default ECR `:latest`) | `string` | `""` | no |
| `dags_bucket_name` | Name of the S3 bucket where DAGs are stored | `string` | n/a | yes |
| `db_endpoint` | RDS PostgreSQL endpoint (`address:port`) | `string` | n/a | yes |
| `db_name` | Airflow metadata database name | `string` | `"airflow"` | no |
| `db_username` | Master username for RDS database | `string` | n/a | yes |
| `db_password` | Master password for RDS database | `string` | n/a | yes |
| `aws_region` | AWS region | `string` | `"us-east-1"` | no |
| `tags` | Key-value map of resource tags | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| `cluster_id` | The ID of the ECS Cluster |
| `cluster_arn` | The ARN of the ECS Cluster |
| `cluster_name` | The name of the ECS Cluster |
| `ecr_repository_url` | The URL of the ECR repository housing Airflow worker container images |
| `ecr_repository_arn` | The ARN of the ECR repository housing Airflow worker container images |
| `task_definition_arn` | The ARN of the base Airflow Worker ECS Task Definition |
| `task_definition_family` | The family name of the base Airflow Worker ECS Task Definition |
| `log_group_name` | The name of the CloudWatch Log Group for worker container logs |
| `log_group_arn` | The ARN of the CloudWatch Log Group for worker container logs |
