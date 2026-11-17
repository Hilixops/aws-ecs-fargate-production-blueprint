# VPC Module (`modules/vpc`)

## Overview

This module provisions a highly available, Multi-AZ Virtual Private Cloud (VPC) topology tailored for Apache Airflow on AWS. It delivers strict network isolation, redundant subnets, controlled internet egress, and a zero-cost S3 Gateway VPC Endpoint to optimize operational expenses (FinOps).

### Architecture Highlights
- **Multi-AZ Availability:** Deploys subnets across at least 2 Availability Zones (`AZ-a` and `AZ-b`).
- **Public Subnets:** Host the Application Load Balancer (ALB) and NAT Gateway, routed directly to an Internet Gateway (`IGW`).
- **Private Subnets:** Host Airflow Core (EC2), ephemeral task workers (ECS Fargate), and metadata databases (Amazon RDS PostgreSQL) without public IPs.
- **FinOps Egress Optimization:** Integrates an `aws_vpc_endpoint` (Gateway type) for Amazon S3 attached directly to the private route table. DAG synchronization and Amazon ECR base image pulls bypass the NAT Gateway, eliminating data processing charges for S3 traffic ($0.00/GB).
- **Centralized Egress:** 1 NAT Gateway with an Elastic IP situated in a public subnet provides outbound connectivity for OS packages, external APIs, and AWS regional service endpoints.

## Usage

```hcl
module "vpc" {
  source = "./modules/vpc"

  name_prefix          = "airflow-production"
  vpc_cidr             = "10.0.0.0/16"
  public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnet_cidrs = ["10.0.10.0/24", "10.0.20.0/24"]

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
| `name_prefix` | Prefix used for naming all resources within the VPC module | `string` | n/a | yes |
| `vpc_cidr` | IPv4 CIDR block for the Virtual Private Cloud (VPC) | `string` | n/a | yes |
| `public_subnet_cidrs` | List of public subnet CIDR blocks (minimum 2 for Multi-AZ) | `list(string)` | n/a | yes |
| `private_subnet_cidrs` | List of private subnet CIDR blocks (minimum 2 for Multi-AZ) | `list(string)` | n/a | yes |
| `tags` | Key-value map of resource tags to be merged with all VPC resources | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| `vpc_id` | The ID of the created VPC |
| `vpc_cidr` | The primary CIDR block of the VPC |
| `public_subnet_ids` | List of IDs of the public subnets distributed across AZs |
| `private_subnet_ids` | List of IDs of the private subnets distributed across AZs |
| `nat_gateway_id` | The ID of the provisioned NAT Gateway |
| `nat_gateway_public_ip` | The public Elastic IP allocated to the NAT Gateway |
| `s3_vpc_endpoint_id` | The ID of the S3 Gateway VPC Endpoint |
| `public_route_table_id` | The ID of the public route table |
| `private_route_table_id` | The ID of the private route table |
