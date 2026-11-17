# ==============================================================================
# ECS Fargate Module: Elastic Ephemeral Workers for AwsEcsExecutor
# Features: ECR Repository, ECS Cluster, CloudWatch Logs, Worker Task Definition
# ==============================================================================

resource "aws_ecr_repository" "airflow_worker" {
  name                 = var.ecr_repository_name
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-ecr-worker"
      Role = "ContainerRegistry"
    }
  )
}

resource "aws_cloudwatch_log_group" "airflow_workers" {
  name              = "/ecs/${var.name_prefix}-workers"
  retention_in_days = var.log_retention_days

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-workers-log-group"
      Role = "Logging"
    }
  )
}

resource "aws_ecs_cluster" "main" {
  name = "${var.name_prefix}-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-cluster"
      Role = "WorkerCompute"
    }
  )
}

locals {
  worker_image = var.container_image != "" ? var.container_image : "${aws_ecr_repository.airflow_worker.repository_url}:latest"
}

resource "aws_ecs_task_definition" "airflow_worker" {
  family                   = "${var.name_prefix}-worker"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = tostring(var.worker_cpu)
  memory                   = tostring(var.worker_memory)
  execution_role_arn       = var.execution_role_arn
  task_role_arn            = var.task_role_arn

  container_definitions = jsonencode([
    {
      name      = "airflow-worker"
      image     = local.worker_image
      essential = true
      environment = [
        {
          name  = "AIRFLOW__CORE__DAGS_FOLDER"
          value = "/opt/airflow/dags"
        },
        {
          name  = "DAGS_S3_BUCKET"
          value = var.dags_bucket_name
        },
        {
          name  = "AWS_DEFAULT_REGION"
          value = var.aws_region
        },
        {
          name  = "AIRFLOW__DATABASE__SQL_ALCHEMY_CONN"
          value = "postgresql+psycopg2://${var.db_username}:${var.db_password}@${var.db_endpoint}/${var.db_name}"
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.airflow_workers.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "worker"
        }
      }
    }
  ])

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-worker-task-def"
      Role = "AirflowWorkerTaskDefinition"
    }
  )
}
