output "db_instance_id" {
  description = "The RDS instance identifier"
  value       = aws_db_instance.airflow.id
}

output "db_instance_arn" {
  description = "The ARN of the RDS instance"
  value       = aws_db_instance.airflow.arn
}

output "db_instance_endpoint" {
  description = "The connection endpoint in address:port format"
  value       = aws_db_instance.airflow.endpoint
}

output "db_instance_address" {
  description = "The hostname address of the RDS PostgreSQL instance"
  value       = aws_db_instance.airflow.address
}

output "db_instance_port" {
  description = "The database port on which the instance accepts connections"
  value       = aws_db_instance.airflow.port
}

output "db_name" {
  description = "The database name of the Airflow metadata store"
  value       = aws_db_instance.airflow.db_name
}

output "db_username" {
  description = "The master username for the database"
  value       = aws_db_instance.airflow.username
}

output "db_subnet_group_name" {
  description = "The name of the DB subnet group"
  value       = aws_db_subnet_group.airflow.name
}

output "db_subnet_group_id" {
  description = "The ID of the DB subnet group"
  value       = aws_db_subnet_group.airflow.id
}
