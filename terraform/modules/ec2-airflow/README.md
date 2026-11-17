# EC2 Airflow Module (`modules/ec2-airflow`)

## Overview

This module provisions the private compute instance running the **Apache Airflow Core Control Plane** (Webserver and Scheduler) using `AwsEcsExecutor` to elastically dispatch tasks to AWS Fargate.

### Architecture Highlights
- **Private Subnet Placement:** Deployed in a private subnet with no public IP assigned.
- **Zero SSH (Port 22 Eliminated):** Administered exclusively through **AWS Systems Manager (SSM Session Manager)** via the attached IAM Instance Profile.
- **`AwsEcsExecutor` Integration:** The Scheduler directly calls `ecs:RunTask` on the Fargate cluster for each scheduled DAG task, eliminating Celery/Redis overhead and reducing idle compute cost to $0.00.
- **Continuous S3 DAG Sync:** Uses an automated systemd timer running `aws s3 sync --delete` every 30 seconds to sync DAG files from the S3 DAGs bucket to local disk (`/opt/airflow/dags/`), removing network latency during *DagBag parsing*.
- **ALB Target Group Registration:** Automatically registers the EC2 instance into the ALB target group on port 8080.

## Usage

```hcl
module "ec2_airflow" {
  source = "./modules/ec2-airflow"

  name_prefix                = "airflow-production"
  instance_type              = "t3.medium"
  private_subnet_id          = module.vpc.private_subnet_ids[0]
  security_group_id          = module.security_groups.airflow_ec2_security_group_id
  iam_instance_profile_name  = module.iam_oidc.ec2_instance_profile_name
  target_group_arn           = module.alb.target_group_arn
  airflow_webserver_port     = 8080

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
| `name_prefix` | Prefix used for naming EC2 instance resources | `string` | n/a | yes |
| `instance_type` | EC2 instance type for Airflow | `string` | `"t3.medium"` | no |
| `ami_id` | Custom AMI ID (optional, defaults to AL2023) | `string` | `null` | no |
| `root_volume_size` | Root EBS gp3 volume size in GiB | `number` | `50` | no |
| `private_subnet_id` | Private subnet ID where the EC2 instance launches | `string` | n/a | yes |
| `security_group_id` | Security group ID attached to the EC2 instance | `string` | n/a | yes |
| `iam_instance_profile_name` | IAM Instance Profile name | `string` | n/a | yes |
| `target_group_arn` | ARN of the ALB Target Group | `string` | n/a | yes |
| `airflow_webserver_port` | Port on which Airflow Webserver listens | `number` | `8080` | no |
| `dags_bucket_name` | Name of the S3 bucket where DAGs are stored | `string` | n/a | yes |
| `db_endpoint` | RDS PostgreSQL endpoint (`address:port`) | `string` | n/a | yes |
| `db_name` | Airflow metadata database name | `string` | `"airflow"` | no |
| `db_username` | Master username for RDS database | `string` | n/a | yes |
| `db_password` | Master password for RDS database | `string` | n/a | yes |
| `ecs_cluster_name` | Name of the ECS Cluster for `AwsEcsExecutor` | `string` | n/a | yes |
| `ecs_task_definition_family` | Task Definition family for worker tasks | `string` | n/a | yes |
| `private_subnet_ids` | List of private subnet IDs for Fargate tasks | `list(string)` | n/a | yes |
| `worker_security_group_id` | Security group ID for Fargate worker tasks | `string` | n/a | yes |
| `aws_region` | AWS region | `string` | `"us-east-1"` | no |
| `tags` | Key-value map of resource tags | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| `instance_id` | The ID of the Airflow Core EC2 instance |
| `instance_private_ip` | The private IPv4 address of the Airflow Core EC2 instance |
| `instance_arn` | The ARN of the Airflow Core EC2 instance |
