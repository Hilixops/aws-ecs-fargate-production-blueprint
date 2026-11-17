output "alb_id" {
  description = "The ID of the Application Load Balancer"
  value       = aws_lb.main.id
}

output "alb_arn" {
  description = "The ARN of the Application Load Balancer"
  value       = aws_lb.main.arn
}

output "alb_dns_name" {
  description = "The DNS name of the Application Load Balancer"
  value       = aws_lb.main.dns_name
}

output "alb_zone_id" {
  description = "The canonical hosted zone ID of the Application Load Balancer"
  value       = aws_lb.main.zone_id
}

output "target_group_arn" {
  description = "The ARN of the Target Group routing to Airflow EC2 Webserver"
  value       = aws_lb_target_group.airflow.arn
}

output "target_group_name" {
  description = "The name of the Target Group routing to Airflow EC2 Webserver"
  value       = aws_lb_target_group.airflow.name
}

output "https_listener_arn" {
  description = "The ARN of the HTTPS listener"
  value       = aws_lb_listener.https.arn
}

output "http_listener_arn" {
  description = "The ARN of the HTTP redirection listener"
  value       = aws_lb_listener.http.arn
}

output "certificate_arn" {
  description = "The ARN of the ACM certificate applied to the HTTPS listener"
  value       = local.effective_certificate_arn
}
