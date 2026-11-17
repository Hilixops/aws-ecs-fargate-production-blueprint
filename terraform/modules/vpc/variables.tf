variable "name_prefix" {
  type        = string
  description = "Prefix used for naming all resources within the VPC module"

  validation {
    condition     = length(trimspace(var.name_prefix)) > 0
    error_message = "The name_prefix variable must not be empty."
  }
}

variable "vpc_cidr" {
  type        = string
  description = "IPv4 CIDR block for the Virtual Private Cloud (VPC)"

  validation {
    condition     = can(cidrnetmask(var.vpc_cidr))
    error_message = "The vpc_cidr variable must be a valid IPv4 CIDR string (e.g. 10.0.0.0/16)."
  }
}

variable "public_subnet_cidrs" {
  type        = list(string)
  description = "List of public subnet CIDR blocks (minimum 2 subnets for Multi-AZ redundancy)"

  validation {
    condition     = length(var.public_subnet_cidrs) >= 2
    error_message = "At least two public subnet CIDRs must be provided for Multi-AZ support."
  }
}

variable "private_subnet_cidrs" {
  type        = list(string)
  description = "List of private subnet CIDR blocks (minimum 2 subnets for Multi-AZ redundancy)"

  validation {
    condition     = length(var.private_subnet_cidrs) >= 2
    error_message = "At least two private subnet CIDRs must be provided for Multi-AZ support."
  }
}

variable "tags" {
  type        = map(string)
  description = "Key-value map of resource tags to be merged with all VPC resources"
  default     = {}
}
