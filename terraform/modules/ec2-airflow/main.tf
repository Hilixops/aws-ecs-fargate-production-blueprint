# ==============================================================================
# EC2 Airflow Module: Private Control Plane (Webserver & Scheduler)
# Features: AwsEcsExecutor, Zero SSH (SSM Session Manager), Continuous S3 DAG Sync
# ==============================================================================

data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

locals {
  subnets_joined = join(",", var.private_subnet_ids)

  user_data = <<-EOF
    #!/bin/bash
    set -euo pipefail

    echo "==> [1/5] Starting SSM Agent and basic OS packages..."
    systemctl enable --now amazon-ssm-agent

    dnf update -y
    dnf install -y python3.11 python3.11-pip python3.11-devel postgresql15 postgresql15-devel gcc git awscli

    echo "==> [2/5] Creating airflow system user and directories..."
    useradd -m -s /bin/bash -d /opt/airflow airflow || true
    mkdir -p /opt/airflow/dags /opt/airflow/logs /opt/airflow/plugins
    chown -R airflow:airflow /opt/airflow

    echo "==> [3/5] Installing Apache Airflow and AWS Provider..."
    sudo -u airflow pip3.11 install --no-cache-dir \
      "apache-airflow==2.9.2" \
      "apache-airflow-providers-amazon>=8.20.0" \
      "apache-airflow-providers-postgres>=5.11.0" \
      "psycopg2-binary>=2.9.9"

    echo "==> [4/5] Configuring Continuous S3 DAG Sync Service..."
    cat <<'SYSTEMD_SYNC' > /etc/systemd/system/airflow-dag-sync.service
    [Unit]
    Description=Synchronize Airflow DAGs from S3 to Local Disk
    After=network.target

    [Service]
    Type=oneshot
    User=airflow
    Group=airflow
    ExecStart=/usr/bin/aws s3 sync --delete s3://${var.dags_bucket_name}/ /opt/airflow/dags/
    SYSTEMD_SYNC

    cat <<'SYSTEMD_TIMER' > /etc/systemd/system/airflow-dag-sync.timer
    [Unit]
    Description=Run Airflow DAG Sync every 30 seconds

    [Timer]
    OnBootSec=10sec
    OnUnitActiveSec=30sec
    Unit=airflow-dag-sync.service

    [Install]
    WantedBy=timers.target
    SYSTEMD_TIMER

    systemctl daemon-reload
    systemctl enable --now airflow-dag-sync.timer

    echo "==> [5/5] Configuring Airflow Core Environment for AwsEcsExecutor..."
    cat <<ENVFILE > /etc/airflow.env
    AIRFLOW_HOME=/opt/airflow
    AIRFLOW__CORE__EXECUTOR=airflow.providers.amazon.aws.executors.ecs.ecs_executor.AwsEcsExecutor
    AIRFLOW__DATABASE__SQL_ALCHEMY_CONN=postgresql+psycopg2://${var.db_username}:${var.db_password}@${var.db_endpoint}/${var.db_name}
    AIRFLOW__WEBSERVER__WEB_SERVER_PORT=${var.airflow_webserver_port}
    AIRFLOW__WEBSERVER__SECRET_KEY=$(openssl rand -hex 32)
    AIRFLOW__CORE__LOAD_EXAMPLES=False
    AIRFLOW__CORE__DAGS_FOLDER=/opt/airflow/dags
    AIRFLOW__AWS_ECS_EXECUTOR__CLUSTER=${var.ecs_cluster_name}
    AIRFLOW__AWS_ECS_EXECUTOR__TASK_DEFINITION=${var.ecs_task_definition_family}
    AIRFLOW__AWS_ECS_EXECUTOR__REGION_NAME=${var.aws_region}
    AIRFLOW__AWS_ECS_EXECUTOR__SUBNETS=${local.subnets_joined}
    AIRFLOW__AWS_ECS_EXECUTOR__SECURITY_GROUPS=${var.worker_security_group_id}
    AIRFLOW__AWS_ECS_EXECUTOR__LAUNCH_TYPE=FARGATE
    AIRFLOW__AWS_ECS_EXECUTOR__ASSIGN_PUBLIC_IP=False
    ENVFILE
    chmod 600 /etc/airflow.env

    cat <<'SYSTEMD_WEBSERVER' > /etc/systemd/system/airflow-webserver.service
    [Unit]
    Description=Airflow Webserver Daemon
    After=network.target

    [Service]
    User=airflow
    Group=airflow
    EnvironmentFile=/etc/airflow.env
    ExecStart=/home/airflow/.local/bin/airflow webserver
    Restart=on-failure
    RestartSec=5s

    [Install]
    WantedBy=multi-user.target
    SYSTEMD_WEBSERVER

    cat <<'SYSTEMD_SCHEDULER' > /etc/systemd/system/airflow-scheduler.service
    [Unit]
    Description=Airflow Scheduler with AwsEcsExecutor
    After=network.target airflow-webserver.service

    [Service]
    User=airflow
    Group=airflow
    EnvironmentFile=/etc/airflow.env
    ExecStart=/home/airflow/.local/bin/airflow scheduler
    Restart=on-failure
    RestartSec=5s

    [Install]
    WantedBy=multi-user.target
    SYSTEMD_SCHEDULER

    # Initial DB migrate and systemd launch
    sudo -u airflow bash -c 'set -a; source /etc/airflow.env; /home/airflow/.local/bin/airflow db migrate || true'
    systemctl daemon-reload
    systemctl enable --now airflow-webserver.service
    systemctl enable --now airflow-scheduler.service

    echo "==> [DONE] Airflow Core EC2 initialized successfully."
  EOF
}

resource "aws_instance" "airflow" {
  ami                         = var.ami_id != null ? var.ami_id : data.aws_ami.amazon_linux_2023.id
  instance_type               = var.instance_type
  subnet_id                   = var.private_subnet_id
  vpc_security_group_ids      = [var.security_group_id]
  iam_instance_profile        = var.iam_instance_profile_name
  associate_public_ip_address = false

  root_block_device {
    volume_size           = var.root_volume_size
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true

    tags = merge(
      var.tags,
      {
        Name = "${var.name_prefix}-ec2-root-disk"
      }
    )
  }

  user_data = local.user_data

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-airflow-ec2"
      Role = "AirflowControlPlane"
    }
  )

  lifecycle {
    ignore_changes = [
      ami
    ]
  }
}

resource "aws_lb_target_group_attachment" "airflow" {
  target_group_arn = var.target_group_arn
  target_id        = aws_instance.airflow.id
  port             = var.airflow_webserver_port
}
