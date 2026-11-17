variable "name_prefix" {
  type        = string
  description = "Prefix used for naming ECS resources and Task Definitions"

  validation {
    condition     = length(trimspace(var.name_prefix)) > 0
    error_message = "The name_prefix variable must not be empty."
  }
}

variable "ecr_repository_name" {
  type        = string
  description = "Name for the ECR repository housing Airflow worker container images"
  default     = "airflow-worker"
}

variable "log_retention_days" {
  type        = number
  description = "Retention period in days for CloudWatch log events"
  default     = 30

  validation {
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365], var.log_retention_days)
    error_message = "The log_retention_days must be a valid CloudWatch retention interval (e.g. 7, 14, 30, 90, 365)."
  }
}

variable "worker_cpu" {
  type        = number
  description = "CPU units allocated for the Airflow worker task (256 = 0.25 vCPU, 512 = 0.5 vCPU, 1024 = 1 vCPU)"
  default     = 512

  validation {
    condition     = contains([256, 512, 1024, 2048, 4096], var.worker_cpu)
    error_message = "worker_cpu must be a valid Fargate CPU value: 256, 512, 1024, 2048, 4096."
  }
}

variable "worker_memory" {
  type        = number
  description = "Memory (in MiB) allocated for the Airflow worker task"
  default     = 1024

  validation {
    condition     = var.worker_memory >= 512 && var.worker_memory <= 30720
    error_message = "worker_memory must be between 512 and 30720 MiB."
  }
}

variable "execution_role_arn" {
  type        = string
  description = "ARN of the ECS Task Execution Role allowing ECS agent to pull images and push logs"

  validation {
    condition     = can(regex("^arn:aws:iam:", var.execution_role_arn))
    error_message = "The execution_role_arn must be a valid IAM Role ARN."
  }
}

variable "task_role_arn" {
  type        = string
  description = "ARN of the ECS Task Role granting runtime permissions to the worker container"

  validation {
    condition     = can(regex("^arn:aws:iam:", var.task_role_arn))
    error_message = "The task_role_arn must be a valid IAM Role ARN."
  }
}

variable "container_image" {
  type        = string
  description = "Custom container image URI. If empty, the provisioned ECR repository URL with :latest will be used"
  default     = ""
}

variable "dags_bucket_name" {
  type        = string
  description = "Name of the S3 bucket where DAGs are stored"
}

variable "db_endpoint" {
  type        = string
  description = "RDS PostgreSQL endpoint in address:port format"
}

variable "db_name" {
  type        = string
  description = "Airflow metadata database name"
  default     = "airflow"
}

variable "db_username" {
  type        = string
  description = "Airflow metadata database master username"
}

variable "db_password" {
  type        = string
  description = "Airflow metadata database master password"
  sensitive   = true
}

variable "aws_region" {
  type        = string
  description = "AWS Region for CloudWatch logs configuration"
  default     = "us-east-1"
}

variable "tags" {
  type        = map(string)
  description = "Key-value map of resource tags to apply across ECS resources"
  default     = {}
}
