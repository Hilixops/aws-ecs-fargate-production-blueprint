# ==============================================================================
# IAM & OIDC Module: Airflow Core EC2, ECS Fargate Workers, and GitHub Actions
# Enforces Least Privilege, IAM Instance Profiles, and zero static credentials.
# ==============================================================================

# ------------------------------------------------------------------------------
# 1. GitHub Actions OIDC Provider & Deployment Role
# ------------------------------------------------------------------------------
resource "aws_iam_openid_connect_provider" "github" {
  count          = var.create_oidc_provider ? 1 : 0
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
  thumbprint_list = [
    "6938fd4d98bab03faadb97b34396831e3780aea1",
    "1c58a21807d4b4a6d47d4e5f22e84ec1f33f6756"
  ]

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-github-oidc-provider"
    }
  )
}

locals {
  oidc_provider_arn = var.create_oidc_provider ? aws_iam_openid_connect_provider.github[0].arn : "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/token.actions.githubusercontent.com"
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

data "aws_iam_policy_document" "github_actions_trust" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    principals {
      type        = "Federated"
      identifiers = [local.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${var.github_repo}:*"]
    }
  }
}

resource "aws_iam_role" "github_actions" {
  name               = "${var.name_prefix}-github-actions-role"
  assume_role_policy = data.aws_iam_policy_document.github_actions_trust.json

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-github-actions-role"
    }
  )
}

data "aws_iam_policy_document" "github_actions_deploy" {
  statement {
    sid    = "ECRAuthToken"
    effect = "Allow"
    actions = [
      "ecr:GetAuthorizationToken"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "ECRImagePush"
    effect = "Allow"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchGetImage",
      "ecr:PutImage",
      "ecr:InitiateLayerUpload",
      "ecr:UploadLayerPart",
      "ecr:CompleteLayerUpload"
    ]
    resources = [var.ecr_repository_arn]
  }

  statement {
    sid    = "S3DAGsSync"
    effect = "Allow"
    actions = [
      "s3:PutObject",
      "s3:GetObject",
      "s3:ListBucket",
      "s3:DeleteObject"
    ]
    resources = [
      var.dags_bucket_arn,
      "${var.dags_bucket_arn}/*"
    ]
  }
}

resource "aws_iam_policy" "github_actions_deploy" {
  name        = "${var.name_prefix}-github-actions-deploy-policy"
  description = "Scoped CI/CD permissions for GitHub Actions to sync DAGs and push ECR images"
  policy      = data.aws_iam_policy_document.github_actions_deploy.json

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-github-actions-deploy-policy"
    }
  )
}

resource "aws_iam_role_policy_attachment" "github_actions_attach" {
  role       = aws_iam_role.github_actions.name
  policy_arn = aws_iam_policy.github_actions_deploy.arn
}

# ------------------------------------------------------------------------------
# 2. EC2 Airflow Core IAM Role & Instance Profile
# Permissions: SSM Session Manager, ecs:RunTask, iam:PassRole, S3 DAGs, Secrets Manager
# ------------------------------------------------------------------------------
data "aws_iam_policy_document" "ec2_trust" {
  statement {
    actions = ["sts:AssumeRole"]
    effect  = "Allow"

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "airflow_ec2" {
  name               = "${var.name_prefix}-airflow-ec2-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_trust.json

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-airflow-ec2-role"
    }
  )
}

# Attach AWS Managed Policy for SSM Session Manager (eliminates SSH port 22)
resource "aws_iam_role_policy_attachment" "airflow_ec2_ssm" {
  role       = aws_iam_role.airflow_ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Custom Policy for Airflow Core (AwsEcsExecutor, S3 DAGs, Secrets Manager)
data "aws_iam_policy_document" "airflow_ec2_core" {
  statement {
    sid    = "AwsEcsExecutorOperations"
    effect = "Allow"
    actions = [
      "ecs:RunTask",
      "ecs:StopTask",
      "ecs:DescribeTasks"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "PassRoleToEcsTasks"
    effect = "Allow"
    actions = [
      "iam:PassRole"
    ]
    resources = [
      aws_iam_role.ecs_task_execution.arn,
      aws_iam_role.ecs_task.arn
    ]
  }

  statement {
    sid    = "S3DAGsContinuousSync"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:ListBucket",
      "s3:GetBucketLocation"
    ]
    resources = [
      var.dags_bucket_arn,
      "${var.dags_bucket_arn}/*"
    ]
  }

  statement {
    sid    = "SecretsManagerAccess"
    effect = "Allow"
    actions = [
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret"
    ]
    resources = [
      "arn:aws:secretsmanager:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:secret:airflow/*",
      "arn:aws:secretsmanager:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:secret:${var.name_prefix}*"
    ]
  }

  statement {
    sid    = "CloudWatchLogsMetrics"
    effect = "Allow"
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogStreams"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "airflow_ec2_core" {
  name        = "${var.name_prefix}-airflow-ec2-core-policy"
  description = "Core permissions for Airflow Webserver and Scheduler using AwsEcsExecutor"
  policy      = data.aws_iam_policy_document.airflow_ec2_core.json

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-airflow-ec2-core-policy"
    }
  )
}

resource "aws_iam_role_policy_attachment" "airflow_ec2_core_attach" {
  role       = aws_iam_role.airflow_ec2.name
  policy_arn = aws_iam_policy.airflow_ec2_core.arn
}

resource "aws_iam_instance_profile" "airflow_ec2" {
  name = "${var.name_prefix}-airflow-ec2-instance-profile"
  role = aws_iam_role.airflow_ec2.name

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-airflow-ec2-instance-profile"
    }
  )
}

# ------------------------------------------------------------------------------
# 3. ECS Fargate Roles: Task Execution Role & Task Role
# ------------------------------------------------------------------------------
data "aws_iam_policy_document" "ecs_tasks_trust" {
  statement {
    actions = ["sts:AssumeRole"]
    effect  = "Allow"

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

# Task Execution Role (Allows ECS agent to pull images and push logs)
resource "aws_iam_role" "ecs_task_execution" {
  name               = "${var.name_prefix}-ecs-task-execution-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_trust.json

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-ecs-task-execution-role"
    }
  )
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_managed" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Task Role (Permissions granted directly to the worker container processes)
resource "aws_iam_role" "ecs_task" {
  name               = "${var.name_prefix}-ecs-task-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_trust.json

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-ecs-task-role"
    }
  )
}

data "aws_iam_policy_document" "ecs_task_permissions" {
  statement {
    sid    = "S3DAGsWorkerSync"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:ListBucket",
      "s3:GetBucketLocation"
    ]
    resources = [
      var.dags_bucket_arn,
      "${var.dags_bucket_arn}/*"
    ]
  }

  statement {
    sid    = "SecretsManagerAirflow"
    effect = "Allow"
    actions = [
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret"
    ]
    resources = [
      "arn:aws:secretsmanager:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:secret:airflow/*",
      "arn:aws:secretsmanager:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:secret:${var.name_prefix}*"
    ]
  }
}

resource "aws_iam_policy" "ecs_task_permissions" {
  name        = "${var.name_prefix}-ecs-task-policy"
  description = "Runtime permissions for Airflow Fargate Worker tasks"
  policy      = data.aws_iam_policy_document.ecs_task_permissions.json

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-ecs-task-policy"
    }
  )
}

resource "aws_iam_role_policy_attachment" "ecs_task_attach" {
  role       = aws_iam_role.ecs_task.name
  policy_arn = aws_iam_policy.ecs_task_permissions.arn
}
