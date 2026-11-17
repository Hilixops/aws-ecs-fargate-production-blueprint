# ==============================================================================
# Security Groups: Micro-segmentation for AWS Apache Airflow Architecture (V5)
# Zero SSH (port 22). Strictly chained security group references.
# ==============================================================================

# ------------------------------------------------------------------------------
# 1. ALB Security Group (Public Ingress)
# ------------------------------------------------------------------------------
resource "aws_security_group" "alb" {
  name        = "${var.name_prefix}-alb-sg"
  description = "Security group for public Application Load Balancer"
  vpc_id      = var.vpc_id

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-alb-sg"
      Role = "LoadBalancer"
    }
  )
}

resource "aws_security_group_rule" "alb_ingress_http" {
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Allow inbound HTTP traffic for redirection to HTTPS"
  security_group_id = aws_security_group.alb.id
}

resource "aws_security_group_rule" "alb_ingress_https" {
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Allow inbound secure HTTPS traffic from the internet"
  security_group_id = aws_security_group.alb.id
}

resource "aws_security_group_rule" "alb_egress_to_ec2" {
  type                     = "egress"
  from_port                = var.airflow_webserver_port
  to_port                  = var.airflow_webserver_port
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.airflow_ec2.id
  description              = "Allow outbound traffic only to Airflow EC2 Webserver"
  security_group_id        = aws_security_group.alb.id
}

# ------------------------------------------------------------------------------
# 2. Airflow EC2 Core Security Group (Webserver & Scheduler)
# No SSH allowed. Administered strictly through AWS Systems Manager (SSM).
# ------------------------------------------------------------------------------
resource "aws_security_group" "airflow_ec2" {
  name        = "${var.name_prefix}-airflow-ec2-sg"
  description = "Security group for Airflow Core EC2 instance (Webserver and Scheduler)"
  vpc_id      = var.vpc_id

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-airflow-ec2-sg"
      Role = "AirflowControlPlane"
    }
  )
}

resource "aws_security_group_rule" "ec2_ingress_from_alb" {
  type                     = "ingress"
  from_port                = var.airflow_webserver_port
  to_port                  = var.airflow_webserver_port
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.alb.id
  description              = "Allow web traffic exclusively from Application Load Balancer"
  security_group_id        = aws_security_group.airflow_ec2.id
}

resource "aws_security_group_rule" "ec2_egress_to_db" {
  type                     = "egress"
  from_port                = var.postgres_port
  to_port                  = var.postgres_port
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.airflow_db.id
  description              = "Allow outbound database connections to Airflow RDS PostgreSQL"
  security_group_id        = aws_security_group.airflow_ec2.id
}

resource "aws_security_group_rule" "ec2_egress_https" {
  type              = "egress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Allow outbound HTTPS for SSM Session Manager, S3 Gateway, and AWS APIs"
  security_group_id = aws_security_group.airflow_ec2.id
}

resource "aws_security_group_rule" "ec2_egress_dns_udp" {
  type              = "egress"
  from_port         = 53
  to_port           = 53
  protocol          = "udp"
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Allow outbound UDP DNS resolution via VPC resolver"
  security_group_id = aws_security_group.airflow_ec2.id
}

resource "aws_security_group_rule" "ec2_egress_dns_tcp" {
  type              = "egress"
  from_port         = 53
  to_port           = 53
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Allow outbound TCP DNS resolution via VPC resolver"
  security_group_id = aws_security_group.airflow_ec2.id
}

# ------------------------------------------------------------------------------
# 3. Airflow Workers Security Group (ECS Fargate Ephemeral Tasks)
# Zero ingress rules. Outbound to DBs, S3 Gateway Endpoint, ECR and NAT.
# ------------------------------------------------------------------------------
resource "aws_security_group" "airflow_workers" {
  name        = "${var.name_prefix}-airflow-workers-sg"
  description = "Security group for ephemeral ECS Fargate Airflow worker tasks"
  vpc_id      = var.vpc_id

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-airflow-workers-sg"
      Role = "AirflowWorkers"
    }
  )
}

resource "aws_security_group_rule" "workers_egress_to_db" {
  type                     = "egress"
  from_port                = var.postgres_port
  to_port                  = var.postgres_port
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.airflow_db.id
  description              = "Allow workers to report task state/heartbeat to Airflow RDS PostgreSQL"
  security_group_id        = aws_security_group.airflow_workers.id
}

resource "aws_security_group_rule" "workers_egress_to_clients_db" {
  type                     = "egress"
  from_port                = var.clients_db_port
  to_port                  = var.clients_db_port
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.clients_db.id
  description              = "Allow workers to execute ETL read/write workloads against Clients Database"
  security_group_id        = aws_security_group.airflow_workers.id
}

resource "aws_security_group_rule" "workers_egress_https" {
  type              = "egress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Allow outbound HTTPS for S3 DAG sync, ECR pull, CloudWatch logs, and AWS APIs"
  security_group_id = aws_security_group.airflow_workers.id
}

resource "aws_security_group_rule" "workers_egress_http" {
  type              = "egress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Allow outbound HTTP for external ETL APIs via NAT Gateway"
  security_group_id = aws_security_group.airflow_workers.id
}

resource "aws_security_group_rule" "workers_egress_dns_udp" {
  type              = "egress"
  from_port         = 53
  to_port           = 53
  protocol          = "udp"
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Allow outbound UDP DNS resolution via VPC resolver"
  security_group_id = aws_security_group.airflow_workers.id
}

resource "aws_security_group_rule" "workers_egress_dns_tcp" {
  type              = "egress"
  from_port         = 53
  to_port           = 53
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Allow outbound TCP DNS resolution via VPC resolver"
  security_group_id = aws_security_group.airflow_workers.id
}

# ------------------------------------------------------------------------------
# 4. Airflow Metadata Database Security Group (Amazon RDS PostgreSQL)
# Ingress permitted ONLY from EC2 Airflow Core and Fargate Airflow Workers.
# ------------------------------------------------------------------------------
resource "aws_security_group" "airflow_db" {
  name        = "${var.name_prefix}-airflow-db-sg"
  description = "Security group for Airflow metadata RDS PostgreSQL database"
  vpc_id      = var.vpc_id

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-airflow-db-sg"
      Role = "MetadataDatabase"
    }
  )
}

resource "aws_security_group_rule" "db_ingress_from_ec2" {
  type                     = "ingress"
  from_port                = var.postgres_port
  to_port                  = var.postgres_port
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.airflow_ec2.id
  description              = "Allow PostgreSQL access strictly from Airflow EC2 Core"
  security_group_id        = aws_security_group.airflow_db.id
}

resource "aws_security_group_rule" "db_ingress_from_workers" {
  type                     = "ingress"
  from_port                = var.postgres_port
  to_port                  = var.postgres_port
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.airflow_workers.id
  description              = "Allow PostgreSQL access strictly from Airflow Fargate Workers"
  security_group_id        = aws_security_group.airflow_db.id
}

# ------------------------------------------------------------------------------
# 5. Clients Database Security Group (Business Databases)
# Ingress permitted strictly from Airflow Workers executing ETL pipelines.
# ------------------------------------------------------------------------------
resource "aws_security_group" "clients_db" {
  name        = "${var.name_prefix}-clients-db-sg"
  description = "Security group for target Clients Databases consumed by Airflow ETL workers"
  vpc_id      = var.vpc_id

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-clients-db-sg"
      Role = "ClientsDatabase"
    }
  )
}

resource "aws_security_group_rule" "clients_db_ingress_from_workers" {
  type                     = "ingress"
  from_port                = var.clients_db_port
  to_port                  = var.clients_db_port
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.airflow_workers.id
  description              = "Allow database ingress strictly from authorized Airflow Fargate Workers"
  security_group_id        = aws_security_group.clients_db.id
}
