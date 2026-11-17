output "bucket_id" {
  description = "The name/ID of the created S3 DAGs bucket"
  value       = aws_s3_bucket.dags.id
}

output "bucket_arn" {
  description = "The ARN of the created S3 DAGs bucket"
  value       = aws_s3_bucket.dags.arn
}

output "bucket_name" {
  description = "The bucket domain name of the S3 DAGs bucket"
  value       = aws_s3_bucket.dags.bucket
}

output "bucket_regional_domain_name" {
  description = "The regional domain name of the S3 DAGs bucket"
  value       = aws_s3_bucket.dags.bucket_regional_domain_name
}
