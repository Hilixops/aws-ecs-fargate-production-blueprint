# ==============================================================================
# S3 DAGs Module: Dedicated Private Bucket for Apache Airflow DAG Storage
# Features: Versioning enabled, SSE-S3 encryption, strict Public Access Block.
# ==============================================================================

resource "aws_s3_bucket" "dags" {
  bucket        = var.bucket_name
  bucket_prefix = var.bucket_name == null ? "${var.name_prefix}-dags-" : null
  force_destroy = var.force_destroy

  tags = merge(
    var.tags,
    {
      Name = var.bucket_name != null ? var.bucket_name : "${var.name_prefix}-dags"
      Role = "AirflowDAGStorage"
    }
  )
}

resource "aws_s3_bucket_versioning" "dags" {
  bucket = aws_s3_bucket.dags.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "dags" {
  bucket = aws_s3_bucket.dags.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "dags" {
  bucket = aws_s3_bucket.dags.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "dags" {
  bucket = aws_s3_bucket.dags.id

  rule {
    id     = "expire-noncurrent-dag-versions"
    status = "Enabled"

    filter {}

    noncurrent_version_expiration {
      noncurrent_days = var.noncurrent_version_expiration_days
    }
  }

  depends_on = [aws_s3_bucket_versioning.dags]
}
