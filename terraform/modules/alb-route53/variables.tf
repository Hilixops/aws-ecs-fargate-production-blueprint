variable "name_prefix" {
  type        = string
  description = "Prefix used for naming ALB and Route 53 resources"

  validation {
    condition     = length(trimspace(var.name_prefix)) > 0
    error_message = "The name_prefix variable must not be empty."
  }
}

variable "vpc_id" {
  type        = string
  description = "VPC ID where the Target Group is created"

  validation {
    condition     = can(regex("^vpc-[a-f0-9]+$", var.vpc_id))
    error_message = "The vpc_id must be a valid AWS VPC identifier starting with 'vpc-'."
  }
}

variable "public_subnet_ids" {
  type        = list(string)
  description = "List of public subnet IDs where the ALB will be deployed (minimum 2)"

  validation {
    condition     = length(var.public_subnet_ids) >= 2
    error_message = "At least two public subnet IDs are required to deploy an Application Load Balancer across AZs."
  }
}

variable "alb_security_group_id" {
  type        = string
  description = "Security group ID attached to the ALB (sg_alb)"

  validation {
    condition     = can(regex("^sg-[a-f0-9]+$", var.alb_security_group_id))
    error_message = "The alb_security_group_id must be a valid AWS Security Group identifier starting with 'sg-'."
  }
}

variable "airflow_webserver_port" {
  type        = number
  description = "TCP port of the Airflow Webserver target (default: 8080)"
  default     = 8080

  validation {
    condition     = var.airflow_webserver_port > 0 && var.airflow_webserver_port <= 65535
    error_message = "The airflow_webserver_port must be between 1 and 65535."
  }
}

variable "health_check_path" {
  type        = string
  description = "Destination path for ALB health check probes"
  default     = "/health"
}

variable "domain_name" {
  type        = string
  description = "Custom domain name (e.g. airflow.example.com). If provided without certificate_arn, an ACM cert is requested"
  default     = null
}

variable "route53_zone_id" {
  type        = string
  description = "Route 53 hosted zone ID for DNS validation and Alias record creation"
  default     = null
}

variable "certificate_arn" {
  type        = string
  description = "Pre-existing ACM Certificate ARN. If provided, overrides domain_name ACM generation"
  default     = null
}

variable "tags" {
  type        = map(string)
  description = "Key-value map of resource tags to be merged with all ALB resources"
  default     = {}
}
