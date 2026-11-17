# Security Groups Module (`modules/security-groups`)

## Overview

This module provides fine-grained, micro-segmented AWS Security Groups strictly aligned with the Apache Airflow Hybrid Blueprint (V5) architecture.

### Security Principles & Rules
1. **Zero SSH (Port 22 Eliminated):** No security group opens port 22. EC2 instances are administered exclusively through **AWS Systems Manager (SSM Session Manager)**.
2. **Strictly Chained Group References:** Rules rely on security group IDs rather than broad IP CIDRs for internal communications.
3. **Least Privilege Ingress:**
   - `sg_alb`: Ingress on 80 and 443 from `0.0.0.0/0`.
   - `sg_airflow_ec2`: Ingress on 8080 **exclusively** from `sg_alb`.
   - `sg_airflow_workers`: **Zero ingress rules**. Workers only make outbound requests.
   - `sg_airflow_db`: Ingress on 5432 **exclusively** from `sg_airflow_ec2` and `sg_airflow_workers`.
   - `sg_clients_db`: Ingress on client database engine port **exclusively** from `sg_airflow_workers`.

### Micro-Segmentation Matrix

| Security Group | Ingress Source | Ports Allowed | Egress Destination | Egress Ports |
|---|---|---|---|---|
| `sg_alb` | `0.0.0.0/0` | 80, 443 | `sg_airflow_ec2` | 8080 |
| `sg_airflow_ec2` | `sg_alb` | 8080 | `sg_airflow_db`, `0.0.0.0/0` | 5432 (DB), 443 (HTTPS), 53 (DNS) |
| `sg_airflow_workers` | *None (Zero Ingress)* | None | `sg_airflow_db`, `sg_clients_db`, `0.0.0.0/0` | 5432 (DB), Clients Port, 443 (HTTPS), 80 (HTTP), 53 (DNS) |
| `sg_airflow_db` | `sg_airflow_ec2`, `sg_airflow_workers` | 5432 | *None* | None |
| `sg_clients_db` | `sg_airflow_workers` | Configurable (5432) | *None* | None |

## Usage

```hcl
module "security_groups" {
  source = "./modules/security-groups"

  name_prefix            = "airflow-production"
  vpc_id                 = module.vpc.vpc_id
  airflow_webserver_port = 8080
  postgres_port          = 5432
  clients_db_port        = 5432

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
| `name_prefix` | Prefix used for naming all security group resources | `string` | n/a | yes |
| `vpc_id` | ID of the VPC where the security groups will be created | `string` | n/a | yes |
| `airflow_webserver_port` | TCP port on which the Airflow Webserver listens | `number` | `8080` | no |
| `postgres_port` | TCP port on which the RDS PostgreSQL database listens | `number` | `5432` | no |
| `clients_db_port` | TCP port on which external business client databases listen | `number` | `5432` | no |
| `tags` | Key-value map of resource tags to be merged with all security groups | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| `alb_security_group_id` | ID of the Application Load Balancer security group (`sg_alb`) |
| `airflow_ec2_security_group_id` | ID of the Airflow Core EC2 security group (`sg_airflow_ec2`) |
| `airflow_workers_security_group_id` | ID of the Airflow ECS Fargate workers security group (`sg_airflow_workers`) |
| `airflow_db_security_group_id` | ID of the Airflow Metadata RDS database security group (`sg_airflow_db`) |
| `clients_db_security_group_id` | ID of the Clients Database security group (`sg_clients_db`) |
