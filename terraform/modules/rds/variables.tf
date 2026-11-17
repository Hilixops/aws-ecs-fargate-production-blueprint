variable "name_prefix" {
  type        = string
  description = "Prefix used for naming all RDS resources"

  validation {
    condition     = length(trimspace(var.name_prefix)) > 0
    error_message = "The name_prefix variable must not be empty."
  }
}

variable "private_subnet_ids" {
  type        = list(string)
  description = "List of private subnet IDs where the DB Subnet Group will be deployed (minimum 2 for Multi-AZ)"

  validation {
    condition     = length(var.private_subnet_ids) >= 2
    error_message = "At least two private subnet IDs must be provided for Multi-AZ RDS deployment."
  }
}

variable "db_security_group_id" {
  type        = string
  description = "Security group ID attached to RDS, permitting access strictly from Airflow EC2 and Workers"

  validation {
    condition     = can(regex("^sg-[a-f0-9]+$", var.db_security_group_id))
    error_message = "The db_security_group_id must be a valid AWS Security Group identifier starting with 'sg-'."
  }
}

variable "db_name" {
  type        = string
  description = "Database name for the Airflow metadata store"
  default     = "airflow"

  validation {
    condition     = can(regex("^[a-zA-Z][a-zA-Z0-9_]*$", var.db_name))
    error_message = "The db_name must begin with a letter and contain only alphanumeric characters or underscores."
  }
}

variable "db_username" {
  type        = string
  description = "Master username for the PostgreSQL database"
  default     = "airflow_admin"

  validation {
    condition     = can(regex("^[a-zA-Z][a-zA-Z0-9_]*$", var.db_username))
    error_message = "The db_username must begin with a letter and contain only alphanumeric characters or underscores."
  }
}

variable "db_password" {
  type        = string
  description = "Master password for the PostgreSQL database (must be at least 8 characters)"
  sensitive   = true

  validation {
    condition     = length(var.db_password) >= 8
    error_message = "The db_password must be at least 8 characters long."
  }
}

variable "engine_version" {
  type        = string
  description = "PostgreSQL engine version"
  default     = "15.7"
}

variable "parameter_group_family" {
  type        = string
  description = "DB parameter group family (e.g. postgres15)"
  default     = "postgres15"
}

variable "instance_class" {
  type        = string
  description = "RDS instance class (e.g. db.t4g.small, db.m6g.large)"
  default     = "db.t4g.small"

  validation {
    condition     = can(regex("^db\\.", var.instance_class))
    error_message = "The instance_class must be a valid RDS instance class starting with 'db.'."
  }
}

variable "allocated_storage" {
  type        = number
  description = "Initial allocated storage in GiB for the RDS instance"
  default     = 20

  validation {
    condition     = var.allocated_storage >= 20
    error_message = "Allocated storage must be at least 20 GiB for PostgreSQL."
  }
}

variable "max_allocated_storage" {
  type        = number
  description = "Maximum storage limit in GiB for storage autoscaling"
  default     = 100

  validation {
    condition     = var.max_allocated_storage >= 20
    error_message = "Max allocated storage must be at least 20 GiB."
  }
}

variable "multi_az" {
  type        = bool
  description = "Specifies if the RDS instance is deployed across multiple AZs for high availability failover"
  default     = false
}

variable "port" {
  type        = number
  description = "TCP port on which PostgreSQL accepts connections"
  default     = 5432

  validation {
    condition     = var.port > 0 && var.port <= 65535
    error_message = "The port must be a valid port number between 1 and 65535."
  }
}

variable "backup_retention_period" {
  type        = number
  description = "Number of days to retain automated backups (0 to 35)"
  default     = 7

  validation {
    condition     = var.backup_retention_period >= 0 && var.backup_retention_period <= 35
    error_message = "The backup_retention_period must be between 0 and 35 days."
  }
}

variable "deletion_protection" {
  type        = bool
  description = "If true, deletion protection will be enabled on the database"
  default     = false
}

variable "skip_final_snapshot" {
  type        = bool
  description = "Determines whether a final DB snapshot is created before the DB instance is deleted"
  default     = true
}

variable "tags" {
  type        = map(string)
  description = "Key-value map of resource tags to be merged with all RDS resources"
  default     = {}
}
