output "instance_id" {
  description = "The ID of the Airflow Core EC2 instance"
  value       = aws_instance.airflow.id
}

output "instance_private_ip" {
  description = "The private IPv4 address of the Airflow Core EC2 instance"
  value       = aws_instance.airflow.private_ip
}

output "instance_arn" {
  description = "The ARN of the Airflow Core EC2 instance"
  value       = aws_instance.airflow.arn
}
