# S3 DAGs Module (`modules/s3-dags`)

## Overview

This module provisions an Amazon S3 bucket dedicated to storing and synchronizing Apache Airflow DAG definitions. It enforces strict security controls, data immutability through versioning, and compliance with AWS Well-Architected best practices.

### Architecture Highlights
- **Continuous Synchronization Target:** Used by CI/CD pipelines to deploy DAG files, and synchronized to local disk by both Airflow EC2 Core (`aws s3 sync --delete`) and ephemeral ECS Fargate worker containers before task execution.
- **Data Protection & Versioning:** Bucket versioning is enabled to preserve code history and enable rollback in case of accidental deletions or corrupt DAG uploads.
- **Server-Side Encryption:** Default encryption using SSE-S3 (`AES256`) with S3 Bucket Keys enabled to reduce KMS request costs.
- **Total Public Access Block:** All four S3 public access block flags are enforced (`block_public_acls`, `block_public_policy`, `ignore_public_acls`, `restrict_public_buckets`).
- **Cost-Optimized Lifecycle:** Automatically expires noncurrent (historical) object versions after a configurable duration (`noncurrent_version_expiration_days`, default 90 days).

## Usage

```hcl
module "s3_dags" {
  source = "./modules/s3-dags"

  name_prefix                        = "airflow-production"
  bucket_name                        = null # Automatically uses bucket_prefix
  force_destroy                      = false
  noncurrent_version_expiration_days = 90

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
| `name_prefix` | Prefix used for naming the S3 DAGs bucket and associated resources | `string` | n/a | yes |
| `bucket_name` | Explicit name for the S3 bucket (if null, prefix is used) | `string` | `null` | no |
| `force_destroy` | Delete all objects to destroy bucket without error | `bool` | `false` | no |
| `noncurrent_version_expiration_days` | Number of days after which noncurrent DAG versions expire | `number` | `90` | no |
| `tags` | Key-value map of resource tags to be merged with all S3 resources | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| `bucket_id` | The name/ID of the created S3 DAGs bucket |
| `bucket_arn` | The ARN of the created S3 DAGs bucket |
| `bucket_name` | The bucket domain name of the S3 DAGs bucket |
| `bucket_regional_domain_name` | The regional domain name of the S3 DAGs bucket |
