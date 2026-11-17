# ALB & Route 53 Module (`modules/alb-route53`)

## Overview

This module provisions an Application Load Balancer (ALB) acting as the public ingress gateway for the **Apache Airflow Webserver**, configured with TLS/HTTPS termination and automatic HTTP-to-HTTPS redirection.

### Architecture Highlights
- **Multi-AZ Public Edge:** Deployed across redundant public subnets and bound strictly to `sg_alb`.
- **Enforced Encryption in Transit (HTTPS 443):** Uses modern TLS 1.3/1.2 cipher suites (`ELBSecurityPolicy-TLS13-1-2-2021-06`).
- **Flexible TLS Certificate Resolution:**
  1. Accepts an existing ACM certificate (`certificate_arn`).
  2. Issues and validates an `aws_acm_certificate` via Route 53 DNS validation when `domain_name` and `route53_zone_id` are provided.
  3. Fallback: Automatically imports a locally generated 2048-bit RSA self-signed TLS certificate into ACM for initial sandbox deployments without custom domains.
- **HTTP (Port 80) Redirection:** Listens on port 80 and immediately issues a permanent `HTTP_301` redirection to `HTTPS 443`.
- **Target Group Integration:** Targets the private Airflow Core EC2 instance on port `8080` with continuous health probes against `/health`.

## Usage

```hcl
module "alb" {
  source = "./modules/alb-route53"

  name_prefix            = "airflow-production"
  vpc_id                 = module.vpc.vpc_id
  public_subnet_ids      = module.vpc.public_subnet_ids
  alb_security_group_id  = module.security_groups.alb_security_group_id
  airflow_webserver_port = 8080
  health_check_path      = "/health"

  domain_name     = "airflow.example.com"
  route53_zone_id = "Z0123456789EXAMPLE"

  tags = {
    Project     = "aws-airflow-ecs-blueprint"
    Environment = "production"
    ManagedBy   = "Terraform"
    Owner       = "Hilixops"
  }
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| `name_prefix` | Prefix used for naming ALB and Route 53 resources | `string` | n/a | yes |
| `vpc_id` | VPC ID where the Target Group is created | `string` | n/a | yes |
| `public_subnet_ids` | List of public subnet IDs (minimum 2) | `list(string)` | n/a | yes |
| `alb_security_group_id` | Security group ID attached to the ALB (`sg_alb`) | `string` | n/a | yes |
| `airflow_webserver_port` | TCP port of the Airflow Webserver target | `number` | `8080` | no |
| `health_check_path` | Destination path for ALB health check probes | `string` | `"/health"` | no |
| `domain_name` | Custom domain name | `string` | `null` | no |
| `route53_zone_id` | Route 53 hosted zone ID | `string` | `null` | no |
| `certificate_arn` | Pre-existing ACM Certificate ARN | `string` | `null` | no |
| `tags` | Key-value map of resource tags | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| `alb_id` | The ID of the Application Load Balancer |
| `alb_arn` | The ARN of the Application Load Balancer |
| `alb_dns_name` | The DNS name of the Application Load Balancer |
| `alb_zone_id` | The canonical hosted zone ID of the Application Load Balancer |
| `target_group_arn` | The ARN of the Target Group routing to Airflow EC2 Webserver |
| `target_group_name` | The name of the Target Group routing to Airflow EC2 Webserver |
| `https_listener_arn` | The ARN of the HTTPS listener |
| `http_listener_arn` | The ARN of the HTTP redirection listener |
| `certificate_arn` | The ARN of the ACM certificate applied to the HTTPS listener |
