variable "name_prefix" {
  type        = string
  description = "Prefix used for naming the S3 DAGs bucket and associated resources"

  validation {
    condition     = length(trimspace(var.name_prefix)) > 0
    error_message = "The name_prefix variable must not be empty."
  }
}

variable "bucket_name" {
  type        = string
  description = "Explicit name for the S3 bucket. If null, bucket_prefix using name_prefix will be generated"
  default     = null

  validation {
    condition     = var.bucket_name == null || can(regex("^[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$", var.bucket_name))
    error_message = "If provided, bucket_name must be between 3 and 63 characters, containing only lowercase letters, numbers, hyphens, and periods."
  }
}

variable "force_destroy" {
  type        = bool
  description = "A boolean that indicates all objects should be deleted from the bucket so that the bucket can be destroyed without error"
  default     = false
}

variable "noncurrent_version_expiration_days" {
  type        = number
  description = "Number of days after which noncurrent (historical) DAG object versions expire"
  default     = 90

  validation {
    condition     = var.noncurrent_version_expiration_days > 0
    error_message = "The noncurrent_version_expiration_days must be greater than 0."
  }
}

variable "tags" {
  type        = map(string)
  description = "Key-value map of resource tags to be merged with all S3 DAG bucket resources"
  default     = {}
}
