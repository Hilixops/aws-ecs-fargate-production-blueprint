output "github_actions_role_arn" {
  description = "ARN of the IAM Role assumed by GitHub Actions via OIDC"
  value       = aws_iam_role.github_actions.arn
}

output "ec2_instance_profile_name" {
  description = "Name of the IAM Instance Profile attached to Airflow Core EC2"
  value       = aws_iam_instance_profile.airflow_ec2.name
}

output "ec2_instance_profile_arn" {
  description = "ARN of the IAM Instance Profile attached to Airflow Core EC2"
  value       = aws_iam_instance_profile.airflow_ec2.arn
}

output "ec2_role_arn" {
  description = "ARN of the IAM Role used by Airflow Core EC2"
  value       = aws_iam_role.airflow_ec2.arn
}

output "ecs_task_execution_role_arn" {
  description = "ARN of the ECS Task Execution Role for Fargate workers"
  value       = aws_iam_role.ecs_task_execution.arn
}

output "ecs_task_role_arn" {
  description = "ARN of the ECS Task Role for Fargate workers"
  value       = aws_iam_role.ecs_task.arn
}
