output "cluster_id" {
  description = "The ID of the ECS Cluster"
  value       = aws_ecs_cluster.main.id
}

output "cluster_arn" {
  description = "The ARN of the ECS Cluster"
  value       = aws_ecs_cluster.main.arn
}

output "cluster_name" {
  description = "The name of the ECS Cluster"
  value       = aws_ecs_cluster.main.name
}

output "ecr_repository_url" {
  description = "The URL of the ECR repository housing Airflow worker container images"
  value       = aws_ecr_repository.airflow_worker.repository_url
}

output "ecr_repository_arn" {
  description = "The ARN of the ECR repository housing Airflow worker container images"
  value       = aws_ecr_repository.airflow_worker.arn
}

output "task_definition_arn" {
  description = "The ARN of the base Airflow Worker ECS Task Definition"
  value       = aws_ecs_task_definition.airflow_worker.arn
}

output "task_definition_family" {
  description = "The family name of the base Airflow Worker ECS Task Definition"
  value       = aws_ecs_task_definition.airflow_worker.family
}

output "log_group_name" {
  description = "The name of the CloudWatch Log Group for worker container logs"
  value       = aws_cloudwatch_log_group.airflow_workers.name
}

output "log_group_arn" {
  description = "The ARN of the CloudWatch Log Group for worker container logs"
  value       = aws_cloudwatch_log_group.airflow_workers.arn
}
