resource "aws_lb" "concourse_lb" {
  name               = "${local.environment}-concourse-web"
  internal           = var.is_internal
  ip_address_type    = "dualstack"
  load_balancer_type = "application"
  subnets            = local.vpc.public_subnets
  security_groups    = [aws_security_group.concourse_lb.id, aws_security_group.concourse_lb_clients.id]
  tags               = merge(local.common_tags, { Name = "${local.name}-lb" })

  //  TODO: Backfill logging bucket once such a thing is correctly defined, somewhere
  //  access_logs {
  //    bucket  = var.logging_bucket
  //    prefix  = "ELBLogs/${local.name}"
  //    enabled = true
  //  }
}

# Concourse web interface incoming ALB
resource "aws_lb_listener" "concourse_https" {
  load_balancer_arn = aws_lb.concourse_lb.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-FS-1-2-Res-2020-10"
  certificate_arn   = aws_acm_certificate.concourse_web_dl.arn

  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      message_body = "FORBIDDEN"
      status_code  = "403"
    }
  }
}

resource "aws_lb_listener_rule" "concourse_https" {
  listener_arn = aws_lb_listener.concourse_https.arn

  # Authenticate action to access the Cognito user pool. Dynamically added if concourse_auth_alb_conf.enable_auth_alb = true
  dynamic "action" {
    for_each = aws_cognito_user_pool.pool

    content {
      type = "authenticate-cognito"

      authenticate_cognito {
        user_pool_arn       = aws_cognito_user_pool.pool[0].arn
        user_pool_client_id = aws_cognito_user_pool_client.client[0].id
        user_pool_domain    = aws_cognito_user_pool_domain.domain[0].domain
      }
    }
  }

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.concourse_web_http.arn
  }

  condition {
    host_header {
      values = [
        local.fqdn,
      ]
    }
  }
}

resource "aws_lb_target_group" "concourse_web_http" {
  name     = "${local.environment}-concourse-web-http"
  port     = var.concourse_web_port
  protocol = "HTTP"
  vpc_id   = local.vpc.vpc_id

  health_check {
    port    = tostring(var.concourse_web_port)
    path    = "/"
    matcher = "200"
  }

  stickiness {
    enabled = false
    type    = "lb_cookie"
  }

  tags = merge(local.common_tags, { Name = local.name })
}

resource "aws_lb_target_group" "web_ssh" {
  name     = "${local.environment}-concourse-web-ssh"
  port     = 2222
  protocol = "TCP"
  vpc_id   = local.vpc.vpc_id

  # TODO healthcheck issues
  # port 2222 is known to log spam failed SSH connections into CloudWatch
  # port 8080 requires a security group rule to allow all traffic from the private subnets ip ranges, as we cannot
  # get the addresses of the NLB, from where the healthchecks originate, which is too broad to be accepted
  health_check {
    port     = tostring(var.concourse_web_port)
    protocol = "TCP"
  }

  # https://github.com/terraform-providers/terraform-provider-aws/issues/9093
  stickiness {
    enabled = false
    type    = "source_ip"
  }

  tags = merge(local.common_tags, { Name = local.name })
}

resource "aws_lb" "internal_lb" {
  name               = "${local.environment}-concourse-internal"
  internal           = true
  load_balancer_type = "network"
  subnets            = local.vpc.private_subnets
  tags               = merge(local.common_tags, { Name = "${local.name}-int-lb" })

  //  TODO: Backfill logging bucket once such a thing is correctly defined, somewhere
  //  access_logs {
  //    bucket  = var.logging_bucket
  //    prefix  = "ELBLogs/${var.name}"
  //    enabled = true
  //  }
}

resource "aws_lb_listener" "ssh" {
  load_balancer_arn = aws_lb.internal_lb.arn
  port              = 2222
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web_ssh.arn
  }
}

### Webhook Load balancer ###

# Webhooks LB
resource "aws_lb" "concourse_hooks_lb" {
  count              = var.concourse_auth_alb_conf.enable_auth_alb == false ? 0 : 1
  name               = "${local.environment}-concourse-hooks"
  internal           = false
  load_balancer_type = "application"
  subnets            = local.vpc.public_subnets
  security_groups    = [aws_security_group.concourse_hooks[0].id]
  tags               = merge(local.common_tags, { Name = "${local.name}-hooks-lb" })
}

resource "aws_lb_listener" "concourse_hooks_https" {
  count             = var.concourse_auth_alb_conf.enable_auth_alb == false ? 0 : 1
  load_balancer_arn = aws_lb.concourse_hooks_lb[0].arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS-1-2-2017-01"
  certificate_arn   = aws_acm_certificate.concourse_hooks_dl[0].arn

  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      message_body = "FORBIDDEN"
      status_code  = "403"
    }
  }
}

resource "aws_lb_listener_rule" "concourse_hooks_https" {
  count        = var.concourse_auth_alb_conf.enable_auth_alb == false ? 0 : 1
  listener_arn = aws_lb_listener.concourse_hooks_https[0].arn

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.concourse_hooks_http[0].arn
  }

  condition {
    host_header {
      values = [
        local.fqdn_hooks,
      ]
    }
  }
}

resource "aws_lb_target_group" "concourse_hooks_http" {
  count    = var.concourse_auth_alb_conf.enable_auth_alb == false ? 0 : 1
  name     = "${local.environment}-concourse-hooks-http"
  port     = var.concourse_web_port
  protocol = "HTTP"
  vpc_id   = local.vpc.vpc_id

  health_check {
    port    = tostring(var.concourse_web_port)
    path    = "/"
    matcher = "200"
  }

  stickiness {
    enabled = false
    type    = "lb_cookie"
  }

  tags = merge(local.common_tags, { Name = local.name })
}
