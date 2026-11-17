output "alb_security_group_id" {
  description = "ID of the Application Load Balancer security group (sg_alb)"
  value       = aws_security_group.alb.id
}

output "airflow_ec2_security_group_id" {
  description = "ID of the Airflow Core EC2 security group (sg_airflow_ec2)"
  value       = aws_security_group.airflow_ec2.id
}

output "airflow_workers_security_group_id" {
  description = "ID of the Airflow ECS Fargate workers security group (sg_airflow_workers)"
  value       = aws_security_group.airflow_workers.id
}

output "airflow_db_security_group_id" {
  description = "ID of the Airflow Metadata RDS database security group (sg_airflow_db)"
  value       = aws_security_group.airflow_db.id
}

output "clients_db_security_group_id" {
  description = "ID of the Clients Database security group (sg_clients_db)"
  value       = aws_security_group.clients_db.id
}
