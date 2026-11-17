# IAM & OIDC Module (`modules/iam-oidc`)

## Overview

This module provisions fine-grained IAM roles, policies, and instance profiles tailored for the **Apache Airflow Hybrid Blueprint (V5)** architecture. It enforces zero static credentials and least-privilege security across all layers:

1. **GitHub Actions OIDC Authentication:** Eliminates static `aws_iam_access_key` by establishing a federated OpenID Connect trust relationship restricted specifically to `repo:<org>/<repo>:*`. Grants permissions to synchronize DAGs to S3 and push container images to Amazon ECR.
2. **Airflow Core EC2 Instance Profile:**
   - **AWS Systems Manager (SSM Session Manager):** Administer EC2 instances securely without opening SSH port 22 or provisioning Bastion hosts.
   - **AwsEcsExecutor Delegation:** Grants `ecs:RunTask`, `ecs:StopTask`, and `ecs:DescribeTasks` on the ECS cluster, and `iam:PassRole` to assign Fargate task roles.
   - **S3 Continuous DAG Sync:** Grants read/list access on the S3 DAGs bucket for local disk synchronization.
   - **Secrets Manager Integration:** Grants read access to Airflow metadata connections and Fernet key secrets.
3. **ECS Fargate Worker Roles:**
   - **Task Execution Role:** Permits the ECS agent to pull container images from ECR and stream logs to CloudWatch.
   - **Task Role:** Grants runtime permissions for container processes to pull DAG definitions from S3 and retrieve credentials from Secrets Manager.

## Usage

```hcl
module "iam_oidc" {
  source = "./modules/iam-oidc"

  name_prefix        = "airflow-production"
  github_repo        = "hilixops/aws-ecs-fargate-production-blueprint"
  ecr_repository_arn = module.ecs_fargate.ecr_repository_arn
  dags_bucket_arn    = module.s3_dags.bucket_arn

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
| `name_prefix` | Prefix used for naming IAM roles and policies | `string` | n/a | yes |
| `github_repo` | GitHub repository path (`org/repo`) authorized via OIDC | `string` | `"hilixops/aws-ecs-fargate-production-blueprint"` | no |
| `ecr_repository_arn` | ARN of the ECR repository for worker images | `string` | n/a | yes |
| `dags_bucket_arn` | ARN of the S3 bucket storing Airflow DAGs | `string` | n/a | yes |
| `create_oidc_provider` | Whether to create the OIDC provider resource | `bool` | `true` | no |
| `tags` | Key-value map of resource tags | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| `github_actions_role_arn` | ARN of the IAM Role assumed by GitHub Actions via OIDC |
| `ec2_instance_profile_name` | Name of the IAM Instance Profile attached to Airflow Core EC2 |
| `ec2_instance_profile_arn` | ARN of the IAM Instance Profile attached to Airflow Core EC2 |
| `ec2_role_arn` | ARN of the IAM Role used by Airflow Core EC2 |
| `ecs_task_execution_role_arn` | ARN of the ECS Task Execution Role for Fargate workers |
| `ecs_task_role_arn` | ARN of the ECS Task Role for Fargate workers |
