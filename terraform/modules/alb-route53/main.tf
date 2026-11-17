# ==============================================================================
# ALB & Route 53 Module: Secure Ingress for Apache Airflow Webserver
# Features: Public Application Load Balancer, HTTPS listener (ACM), HTTP->HTTPS redirect
# ==============================================================================

resource "aws_lb" "main" {
  name_prefix                = substr("${var.name_prefix}-alb", 0, 6)
  internal                   = false
  load_balancer_type         = "application"
  security_groups            = [var.alb_security_group_id]
  subnets                    = var.public_subnet_ids
  drop_invalid_header_fields = true

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-alb"
      Role = "PublicIngress"
    }
  )
}

resource "aws_lb_target_group" "airflow" {
  name_prefix          = "af-tg-"
  port                 = var.airflow_webserver_port
  protocol             = "HTTP"
  vpc_id               = var.vpc_id
  target_type          = "instance"
  deregistration_delay = 30

  health_check {
    enabled             = true
    path                = var.health_check_path
    port                = "traffic-port"
    protocol            = "HTTP"
    matcher             = "200,302"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-airflow-tg"
      Role = "TargetGroup"
    }
  )

  lifecycle {
    create_before_destroy = true
  }
}

# ------------------------------------------------------------------------------
# TLS Certificate Resolution (Existing ARN, Route 53 ACM, or Self-Signed Fallback)
# ------------------------------------------------------------------------------
locals {
  use_existing_cert = var.certificate_arn != null
  use_route53_acm   = !local.use_existing_cert && var.domain_name != null
  use_self_signed   = !local.use_existing_cert && !local.use_route53_acm
}

# 1. Route 53 ACM Certificate (for custom domains)
resource "aws_acm_certificate" "route53" {
  count             = local.use_route53_acm ? 1 : 0
  domain_name       = var.domain_name
  validation_method = "DNS"

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-acm-cert"
    }
  )

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "cert_validation" {
  for_each = local.use_route53_acm && var.route53_zone_id != null ? {
    for dvo in aws_acm_certificate.route53[0].domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  } : {}

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = var.route53_zone_id
}

resource "aws_acm_certificate_validation" "route53" {
  count                   = local.use_route53_acm && var.route53_zone_id != null ? 1 : 0
  certificate_arn         = aws_acm_certificate.route53[0].arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
}

# 2. Self-Signed Certificate imported to ACM (for sandbox deployments without domain)
resource "tls_private_key" "self_signed" {
  count     = local.use_self_signed ? 1 : 0
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_self_signed_cert" "self_signed" {
  count           = local.use_self_signed ? 1 : 0
  private_key_pem = tls_private_key.self_signed[0].private_key_pem

  subject {
    common_name  = "airflow.local"
    organization = "Hilixops"
  }

  validity_period_hours = 8760 # 1 year

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
  ]
}

resource "aws_acm_certificate" "self_signed" {
  count            = local.use_self_signed ? 1 : 0
  private_key      = tls_private_key.self_signed[0].private_key_pem
  certificate_body = tls_self_signed_cert.self_signed[0].cert_pem

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-self-signed-cert"
    }
  )

  lifecycle {
    create_before_destroy = true
  }
}

locals {
  effective_certificate_arn = local.use_existing_cert ? var.certificate_arn : (
    local.use_route53_acm ? (
      var.route53_zone_id != null ? aws_acm_certificate_validation.route53[0].certificate_arn : aws_acm_certificate.route53[0].arn
    ) : aws_acm_certificate.self_signed[0].arn
  )
}

# ------------------------------------------------------------------------------
# Listeners: HTTPS (443) and HTTP (80) Redirection
# ------------------------------------------------------------------------------
resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.main.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = local.effective_certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.airflow.arn
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-https-listener"
    }
  )
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-http-redirect-listener"
    }
  )
}

# ------------------------------------------------------------------------------
# Route 53 Custom Domain Record (Optional)
# ------------------------------------------------------------------------------
resource "aws_route53_record" "alb" {
  count   = var.domain_name != null && var.route53_zone_id != null ? 1 : 0
  zone_id = var.route53_zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = aws_lb.main.dns_name
    zone_id                = aws_lb.main.zone_id
    evaluate_target_health = true
  }
}
