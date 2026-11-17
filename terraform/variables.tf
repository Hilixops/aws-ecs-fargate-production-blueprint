# ==============================================================================
# Global Root Variables: AWS Apache Airflow Hybrid Blueprint
# ==============================================================================

variable "aws_region" {
  type        = string
  description = "Target AWS Region for provisioning all infrastructure resources"
  default     = "us-east-1"

  validation {
    condition     = can(regex("^[a-z]{2}-[a-z]+-\\d{1}$", var.aws_region))
    error_message = "The aws_region variable must follow standard AWS region naming convention (e.g. us-east-1, eu-west-1)."
  }
}

variable "environment" {
  type        = string
  description = "Deployment target environment (production, staging, dev)"
  default     = "production"

  validation {
    condition     = contains(["production", "staging", "dev"], var.environment)
    error_message = "Environment must be one of: production, staging, dev."
  }
}

variable "project_name" {
  type        = string
  description = "Short project identifier used as a prefix for named resources"
  default     = "airflow-blueprint"

  validation {
    condition     = length(trimspace(var.project_name)) > 0
    error_message = "The project_name variable must not be empty."
  }
}

# ------------------------------------------------------------------------------
# Networking (VPC) Variables
# ------------------------------------------------------------------------------
variable "vpc_cidr" {
  type        = string
  description = "Primary IPv4 CIDR block for the VPC"
  default     = "10.0.0.0/16"

  validation {
    condition     = can(cidrnetmask(var.vpc_cidr))
    error_message = "The vpc_cidr must be a valid IPv4 CIDR string (e.g. 10.0.0.0/16)."
  }
}

variable "public_subnet_cidrs" {
  type        = list(string)
  description = "List of CIDR blocks for public subnets (minimum 2 across separate AZs)"
  default     = ["10.0.1.0/24", "10.0.2.0/24"]

  validation {
    condition     = length(var.public_subnet_cidrs) >= 2
    error_message = "At least two public subnet CIDRs are required for Multi-AZ redundancy."
  }
}

variable "private_subnet_cidrs" {
  type        = list(string)
  description = "List of CIDR blocks for private subnets (minimum 2 across separate AZs)"
  default     = ["10.0.10.0/24", "10.0.20.0/24"]

  validation {
    condition     = length(var.private_subnet_cidrs) >= 2
    error_message = "At least two private subnet CIDRs are required for Multi-AZ redundancy."
  }
}

# ------------------------------------------------------------------------------
# Security & Network Ports Variables
# ------------------------------------------------------------------------------
variable "airflow_webserver_port" {
  type        = number
  description = "TCP port for the Airflow Webserver interface"
  default     = 8080

  validation {
    condition     = var.airflow_webserver_port > 0 && var.airflow_webserver_port <= 65535
    error_message = "The airflow_webserver_port must be a valid port number between 1 and 65535."
  }
}

variable "postgres_port" {
  type        = number
  description = "TCP port on which PostgreSQL accepts incoming connections"
  default     = 5432

  validation {
    condition     = var.postgres_port > 0 && var.postgres_port <= 65535
    error_message = "The postgres_port must be a valid port number between 1 and 65535."
  }
}

variable "clients_db_port" {
  type        = number
  description = "TCP port for external business databases consumed by ETL workers"
  default     = 5432

  validation {
    condition     = var.clients_db_port > 0 && var.clients_db_port <= 65535
    error_message = "The clients_db_port must be a valid port number between 1 and 65535."
  }
}

# ------------------------------------------------------------------------------
# Database (RDS PostgreSQL) Variables
# ------------------------------------------------------------------------------
variable "db_name" {
  type        = string
  description = "Name of the default database created on RDS PostgreSQL for Airflow metadata"
  default     = "airflow"

  validation {
    condition     = can(regex("^[a-zA-Z][a-zA-Z0-9_]*$", var.db_name))
    error_message = "The db_name must start with a letter and contain only alphanumeric characters or underscores."
  }
}

variable "db_username" {
  type        = string
  description = "Master administrative username for PostgreSQL"
  default     = "airflow_admin"

  validation {
    condition     = can(regex("^[a-zA-Z][a-zA-Z0-9_]*$", var.db_username))
    error_message = "The db_username must start with a letter and contain only alphanumeric characters or underscores."
  }
}

variable "db_password" {
  type        = string
  description = "Master administrative password for PostgreSQL (minimum 8 characters)"
  sensitive   = true

  validation {
    condition     = length(var.db_password) >= 8
    error_message = "The db_password must be at least 8 characters in length."
  }
}

variable "db_instance_class" {
  type        = string
  description = "Compute and memory capacity instance class for RDS PostgreSQL"
  default     = "db.t4g.small"

  validation {
    condition     = can(regex("^db\\.", var.db_instance_class))
    error_message = "The db_instance_class must be a valid RDS instance class starting with 'db.'."
  }
}

variable "db_allocated_storage" {
  type        = number
  description = "Initial allocated storage in GiB for the RDS instance"
  default     = 20

  validation {
    condition     = var.db_allocated_storage >= 20
    error_message = "Allocated storage must be at least 20 GiB for PostgreSQL."
  }
}

variable "db_max_allocated_storage" {
  type        = number
  description = "Maximum storage upper limit in GiB for storage autoscaling"
  default     = 100

  validation {
    condition     = var.db_max_allocated_storage >= 20
    error_message = "Max allocated storage must be at least 20 GiB."
  }
}

variable "db_multi_az" {
  type        = bool
  description = "Enables synchronous Multi-AZ replica deployment for high availability failover"
  default     = false
}

variable "db_backup_retention_period" {
  type        = number
  description = "Number of days automated database backups are retained"
  default     = 7

  validation {
    condition     = var.db_backup_retention_period >= 0 && var.db_backup_retention_period <= 35
    error_message = "The backup retention period must be between 0 and 35 days."
  }
}

variable "db_deletion_protection" {
  type        = bool
  description = "Prevents accidental database deletion when set to true"
  default     = false
}

variable "db_skip_final_snapshot" {
  type        = bool
  description = "Determines whether to skip the final DB snapshot upon teardown"
  default     = true
}

# ------------------------------------------------------------------------------
# Storage (S3 DAGs) Variables
# ------------------------------------------------------------------------------
variable "dags_bucket_name" {
  type        = string
  description = "Explicit name for the S3 DAGs bucket (null for automated bucket_prefix)"
  default     = null

  validation {
    condition     = var.dags_bucket_name == null || can(regex("^[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$", var.dags_bucket_name))
    error_message = "If specified, dags_bucket_name must be between 3 and 63 characters, containing only lowercase letters, numbers, hyphens, and periods."
  }
}

variable "dags_bucket_force_destroy" {
  type        = bool
  description = "Whether to allow destroying the DAGs bucket even if it contains objects"
  default     = false
}

# ------------------------------------------------------------------------------
# IAM & CI/CD Variables
# ------------------------------------------------------------------------------
variable "github_repo" {
  type        = string
  description = "GitHub repository string for OIDC trust relationship (format: org/repo)"
  default     = "hilixops/aws-ecs-fargate-production-blueprint"

  validation {
    condition     = can(regex("^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$", var.github_repo))
    error_message = "The github_repo must follow the 'organization/repository' format."
  }
}

variable "create_oidc_provider" {
  type        = bool
  description = "Whether to create the GitHub Actions OIDC provider resource in IAM"
  default     = true
}

# ------------------------------------------------------------------------------
# Load Balancer & Ingress Variables
# ------------------------------------------------------------------------------
variable "domain_name" {
  type        = string
  description = "Custom domain name for the Airflow Webserver (e.g. airflow.example.com)"
  default     = null
}

variable "route53_zone_id" {
  type        = string
  description = "Route 53 hosted zone ID for custom domain routing and ACM DNS validation"
  default     = null
}

variable "certificate_arn" {
  type        = string
  description = "Existing ACM Certificate ARN (if null, ACM or self-signed cert is used)"
  default     = null
}

# ------------------------------------------------------------------------------
# Airflow Core EC2 Variables
# ------------------------------------------------------------------------------
variable "ec2_instance_type" {
  type        = string
  description = "EC2 instance type for Airflow Webserver and Scheduler"
  default     = "t3.medium"
}

variable "ec2_root_volume_size" {
  type        = number
  description = "Root gp3 volume size in GiB for Airflow EC2 instance"
  default     = 50

  validation {
    condition     = var.ec2_root_volume_size >= 20
    error_message = "The ec2_root_volume_size must be at least 20 GiB."
  }
}

variable "ec2_ami_id" {
  type        = string
  description = "Custom AMI ID for Airflow EC2 instance (defaults to latest Amazon Linux 2023)"
  default     = null
}

# ------------------------------------------------------------------------------
# ECS Fargate Worker Variables
# ------------------------------------------------------------------------------
variable "ecr_repository_name" {
  type        = string
  description = "Name for the ECR repository housing Airflow worker container images"
  default     = "airflow-worker"
}

variable "worker_cpu" {
  type        = number
  description = "CPU units for ephemeral Airflow Fargate worker tasks (512 = 0.5 vCPU)"
  default     = 512

  validation {
    condition     = contains([256, 512, 1024, 2048, 4096], var.worker_cpu)
    error_message = "worker_cpu must be one of: 256, 512, 1024, 2048, 4096."
  }
}

variable "worker_memory" {
  type        = number
  description = "Memory (in MiB) for ephemeral Airflow Fargate worker tasks"
  default     = 1024

  validation {
    condition     = var.worker_memory >= 512 && var.worker_memory <= 30720
    error_message = "worker_memory must be between 512 and 30720 MiB."
  }
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

variable "tags" {
  type        = map(string)
  description = "Additional custom resource tags merged across all resources"
  default     = {}
}
