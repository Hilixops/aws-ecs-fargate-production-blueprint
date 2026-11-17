variable "name_prefix" {
  type        = string
  description = "Prefix used for naming all security group resources"

  validation {
    condition     = length(trimspace(var.name_prefix)) > 0
    error_message = "The name_prefix variable must not be empty."
  }
}

variable "vpc_id" {
  type        = string
  description = "ID of the VPC where the security groups will be created"

  validation {
    condition     = can(regex("^vpc-[a-f0-9]+$", var.vpc_id))
    error_message = "The vpc_id must be a valid AWS VPC identifier starting with 'vpc-'."
  }
}

variable "airflow_webserver_port" {
  type        = number
  description = "TCP port on which the Airflow Webserver listens (default: 8080)"
  default     = 8080

  validation {
    condition     = var.airflow_webserver_port > 0 && var.airflow_webserver_port <= 65535
    error_message = "The airflow_webserver_port must be a valid port number between 1 and 65535."
  }
}

variable "postgres_port" {
  type        = number
  description = "TCP port on which the RDS PostgreSQL database listens (default: 5432)"
  default     = 5432

  validation {
    condition     = var.postgres_port > 0 && var.postgres_port <= 65535
    error_message = "The postgres_port must be a valid port number between 1 and 65535."
  }
}

variable "clients_db_port" {
  type        = number
  description = "TCP port on which external business client databases listen (default: 5432)"
  default     = 5432

  validation {
    condition     = var.clients_db_port > 0 && var.clients_db_port <= 65535
    error_message = "The clients_db_port must be a valid port number between 1 and 65535."
  }
}

variable "tags" {
  type        = map(string)
  description = "Key-value map of resource tags to be merged with all security groups"
  default     = {}
}
