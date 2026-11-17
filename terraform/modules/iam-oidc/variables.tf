variable "name_prefix" {
  type        = string
  description = "Prefix used for naming IAM roles and policies"

  validation {
    condition     = length(trimspace(var.name_prefix)) > 0
    error_message = "The name_prefix variable must not be empty."
  }
}

variable "github_repo" {
  type        = string
  description = "GitHub repository path (org/repo) authorized to assume the deployment role"
  default     = "hilixops/aws-ecs-fargate-production-blueprint"

  validation {
    condition     = can(regex("^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$", var.github_repo))
    error_message = "The github_repo must follow the 'organization/repository' format."
  }
}

variable "ecr_repository_arn" {
  type        = string
  description = "ARN of the ECR repository that GitHub Actions pushes worker images to"

  validation {
    condition     = can(regex("^arn:aws:ecr:", var.ecr_repository_arn))
    error_message = "The ecr_repository_arn must be a valid ECR repository ARN."
  }
}

variable "dags_bucket_arn" {
  type        = string
  description = "ARN of the S3 bucket storing Airflow DAGs"

  validation {
    condition     = can(regex("^arn:aws:s3:::", var.dags_bucket_arn))
    error_message = "The dags_bucket_arn must be a valid S3 bucket ARN."
  }
}

variable "create_oidc_provider" {
  type        = bool
  description = "Whether to create the GitHub Actions OIDC provider resource (set false if already exists in account)"
  default     = true
}

variable "tags" {
  type        = map(string)
  description = "Key-value map of resource tags to be merged with all IAM resources"
  default     = {}
}
