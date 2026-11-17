variable "name_prefix" {
  type        = string
  description = "Prefix used for naming EC2 instance resources"

  validation {
    condition     = length(trimspace(var.name_prefix)) > 0
    error_message = "The name_prefix variable must not be empty."
  }
}

variable "instance_type" {
  type        = string
  description = "EC2 instance type for Airflow Webserver and Scheduler"
  default     = "t3.medium"
}

variable "ami_id" {
  type        = string
  description = "Custom AMI ID (optional, defaults to latest Amazon Linux 2023)"
  default     = null
}

variable "root_volume_size" {
  type        = number
  description = "Root EBS gp3 volume size in GiB"
  default     = 50

  validation {
    condition     = var.root_volume_size >= 20
    error_message = "Root volume size must be at least 20 GiB."
  }
}

variable "private_subnet_id" {
  type        = string
  description = "Private subnet ID where the EC2 instance will be launched"

  validation {
    condition     = can(regex("^subnet-[a-f0-9]+$", var.private_subnet_id))
    error_message = "The private_subnet_id must be a valid AWS Subnet ID starting with 'subnet-'."
  }
}

variable "security_group_id" {
  type        = string
  description = "Security group ID attached to the EC2 instance (sg_airflow_ec2)"

  validation {
    condition     = can(regex("^sg-[a-f0-9]+$", var.security_group_id))
    error_message = "The security_group_id must be a valid AWS Security Group ID starting with 'sg-'."
  }
}

variable "iam_instance_profile_name" {
  type        = string
  description = "IAM Instance Profile name granting SSM, ECS RunTask, and S3 permissions"
}

variable "target_group_arn" {
  type        = string
  description = "ARN of the ALB Target Group to attach the EC2 instance to"
}

variable "airflow_webserver_port" {
  type        = number
  description = "Port on which the Airflow Webserver listens"
  default     = 8080

  validation {
    condition     = var.airflow_webserver_port > 0 && var.airflow_webserver_port <= 65535
    error_message = "The airflow_webserver_port must be between 1 and 65535."
  }
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

variable "ecs_cluster_name" {
  type        = string
  description = "Name of the ECS Cluster for AwsEcsExecutor"
}

variable "ecs_task_definition_family" {
  type        = string
  description = "Task Definition family used by AwsEcsExecutor to run Fargate worker tasks"
}

variable "private_subnet_ids" {
  type        = list(string)
  description = "List of private subnet IDs where Fargate tasks will be provisioned by AwsEcsExecutor"
}

variable "worker_security_group_id" {
  type        = string
  description = "Security group ID assigned to Fargate worker tasks (sg_airflow_workers)"
}

variable "aws_region" {
  type        = string
  description = "AWS region for AwsEcsExecutor"
  default     = "us-east-1"
}

variable "tags" {
  type        = map(string)
  description = "Key-value map of resource tags"
  default     = {}
}
