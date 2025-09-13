resource "aws_security_group" "concourse_lb" {
  vpc_id = local.vpc.vpc_id
  tags   = merge(local.common_tags, { Name = "${local.name}-lb" })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group" "concourse_lb_clients" {
  name   = "${local.environment}-ConcourseWeb-user-ips"
  vpc_id = local.vpc.vpc_id
  tags   = merge(local.common_tags, { Name = "${local.name}-clients" })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group" "concourse_web" {
  name        = "${local.environment}-ConcourseWeb"
  description = "Concourse Web Nodes"
  vpc_id      = local.vpc.vpc_id
  tags        = merge(local.common_tags, { Name = local.name })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group" "concourse_worker" {
  name        = "${local.environment}-ConcourseWorker"
  description = "ConcourseWorker"
  vpc_id      = local.vpc.vpc_id
  tags        = merge(local.common_tags, { Name = "${local.name}-lb" })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group" "concourse_vpc_endpoints" {
  name        = "${local.environment}-ConcourseVPCEndpoints"
  description = "Concourse VPC Endpoints"
  vpc_id      = local.vpc.vpc_id
  tags        = merge(local.common_tags, { Name = local.name })

  lifecycle {
    create_before_destroy = true
  }
}

//resource "aws_security_group_rule" "internal_ssh_from_bastion_egress" {
//  from_port                = 22
//  protocol                 = "tcp"
//  source_security_group_id = aws_security_group.concourse_vpc_endpoints.id
//  to_port                  = 22
//  type                     = "ingress"
//  security_group_id        = aws_security_group.concourse_web.id
//}

resource "aws_security_group_rule" "lb_external_https_in" {
  description       = "enable inbound connectivity from whitelisted endpoints"
  type              = "ingress"
  protocol          = "tcp"
  from_port         = 443
  to_port           = 443
  security_group_id = aws_security_group.concourse_lb.id
  cidr_blocks       = var.whitelist_cidr_blocks
}

resource "aws_security_group_rule" "web_lb_in_http" {
  description              = "inbound traffic to web nodes from lb"
  type                     = "ingress"
  protocol                 = "tcp"
  from_port                = var.concourse_web_port
  to_port                  = var.concourse_web_port
  security_group_id        = aws_security_group.concourse_web.id
  source_security_group_id = aws_security_group.concourse_lb.id
}

resource "aws_security_group_rule" "lb_web_out_http" {
  description              = "outbound traffic from web nodes to lb"
  type                     = "egress"
  protocol                 = "tcp"
  from_port                = var.concourse_web_port
  to_port                  = var.concourse_web_port
  security_group_id        = aws_security_group.concourse_lb.id
  source_security_group_id = aws_security_group.concourse_web.id
}

resource "aws_security_group_rule" "int_lb_web_in_http" {
  description       = "inbound traffic to web nodes from internal lb"
  type              = "ingress"
  protocol          = "tcp"
  from_port         = var.concourse_web_port
  to_port           = var.concourse_web_port
  security_group_id = aws_security_group.concourse_web.id
  cidr_blocks       = local.vpc.private_subnets_cidr_blocks
}

resource "aws_security_group_rule" "web_internal_in_tcp" {
  description              = "allow web nodes to communicate with each other"
  type                     = "ingress"
  protocol                 = "tcp"
  from_port                = 0
  to_port                  = 65535
  security_group_id        = aws_security_group.concourse_web.id
  source_security_group_id = aws_security_group.concourse_web.id
}

resource "aws_security_group_rule" "web_internal_out_tcp" {
  description              = "web_internal_out_tcp"
  type                     = "egress"
  protocol                 = "tcp"
  from_port                = 0
  to_port                  = 65535
  security_group_id        = aws_security_group.concourse_web.id
  source_security_group_id = aws_security_group.concourse_web.id
}

resource "aws_security_group_rule" "web_internal_out_all" {
  description       = "web_internal_out_all"
  type              = "egress"
  protocol          = "all"
  from_port         = 0
  to_port           = 65535
  security_group_id = aws_security_group.concourse_web.id
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "worker_internal_out_all" {
  description       = "worker_internal_out_all"
  type              = "egress"
  protocol          = "all"
  from_port         = 0
  to_port           = 65535
  security_group_id = aws_security_group.concourse_worker.id
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "web_lb_in_ssh" {
  description       = "inbound traffic to web nodes from worker nodes via lb"
  type              = "ingress"
  protocol          = "tcp"
  from_port         = 2222
  to_port           = 2222
  security_group_id = aws_security_group.concourse_web.id
  cidr_blocks       = local.vpc.private_subnets_cidr_blocks
}

resource "aws_security_group_rule" "web_db_out" {
  description              = "outbound connectivity from web nodes to db"
  type                     = "egress"
  protocol                 = "tcp"
  from_port                = 5432
  to_port                  = 5432
  security_group_id        = aws_security_group.concourse_web.id
  source_security_group_id = local.database.security_group_id
}

resource "aws_security_group_rule" "web_outbound_s3_https" {
  description       = "s3 outbound https connectivity"
  type              = "egress"
  protocol          = "tcp"
  from_port         = 443
  to_port           = 443
  security_group_id = aws_security_group.concourse_web.id
  prefix_list_ids   = [local.vpc.vpc_endpoint_s3_pl_id]
}

resource "aws_security_group_rule" "web_outbound_s3_http" {
  description       = "s3 outbound http connectivity (for YUM updates)"
  type              = "egress"
  protocol          = "tcp"
  from_port         = 80
  to_port           = 80
  security_group_id = aws_security_group.concourse_web.id
  prefix_list_ids   = [local.vpc.vpc_endpoint_s3_pl_id]
}

//resource "aws_security_group_rule" "web_lb_in_metrics" {
//  description       = "inbound traffic to web nodes metrics port"
//  from_port         = 9090
//  protocol          = "tcp"
//  security_group_id = aws_security_group.concourse_web.id
//  to_port           = 9090
//  type              = "ingress"
//  // TODO: Implement some kinda metrics infra and point this towards it
//  cidr_blocks = var.vpc.aws_subnets_private.*.cidr_block
//}

resource "aws_security_group_rule" "worker_lb_out_ssh" {
  description       = "outbound traffic to web nodes from worker nodes via lb"
  type              = "egress"
  protocol          = "tcp"
  from_port         = 2222
  to_port           = 2222
  security_group_id = aws_security_group.concourse_worker.id
  cidr_blocks       = local.vpc.private_subnets_cidr_blocks
}

resource "aws_security_group_rule" "worker_outbound_s3_https" {
  description       = "s3 outbound https connectivity"
  type              = "egress"
  protocol          = "tcp"
  from_port         = 443
  to_port           = 443
  security_group_id = aws_security_group.concourse_worker.id
  prefix_list_ids   = [local.vpc.vpc_endpoint_s3_pl_id]
}

resource "aws_security_group_rule" "worker_outbound_s3_http" {
  count             = var.create_vpc || var.vpc_endpoint_s3_pl_id != "" ? 1 : 0
  description       = "s3 outbound http connectivity (for YUM updates)"
  type              = "egress"
  protocol          = "tcp"
  from_port         = 80
  to_port           = 80
  security_group_id = aws_security_group.concourse_worker.id
  prefix_list_ids   = [local.vpc.vpc_endpoint_s3_pl_id]
}

resource "aws_security_group_rule" "web_outbound_dynamodb_https" {
  count             = var.create_vpc || var.vpc_endpoint_dynamodb_pl_id != "" ? 1 : 0
  description       = "dynamodb outbound https connectivity"
  type              = "egress"
  protocol          = "tcp"
  from_port         = 443
  to_port           = 443
  security_group_id = aws_security_group.concourse_worker.id
  prefix_list_ids   = [local.vpc.vpc_endpoint_dynamodb_pl_id]
}

//resource "aws_security_group_rule" "worker_ec2_packer_ssh" {
//  description       = "Allow EC2 instances to receive SSH traffic"
//  type              = "ingress"
//  protocol          = "tcp"
//  from_port         = 22
//  to_port           = 22
//  self              = true
//  security_group_id = aws_security_group.concourse_worker.id
//}

### Authenticating Load Balancer Configuration ###

# Added for connectivity back to the Cognito IdP when we are using the Authenticating ALB option
# SG is provisioned if concourse_auth_alb_conf.enable_auth_alb = true
resource "aws_security_group_rule" "lb_web_out_https_cognito" {
  count             = var.concourse_auth_alb_conf.enable_auth_alb == false ? 0 : 1
  description       = "outbound traffic from lb to cognito"
  type              = "egress"
  protocol          = "tcp"
  from_port         = 443
  to_port           = 443
  security_group_id = aws_security_group.concourse_lb.id
  cidr_blocks       = var.concourse_auth_alb_conf.auth_alb_idp_ip_whitelist
}

### Webhook Load balancer ###

# Webhooks security groups
#
# Incoming to LB port 443 from whitelisted IP's (GitHub webhook ip ranges)
# Outgoing from LB port 8080 to Concourse Web node(s)
#
# Incoming to EC2 port 8080 from webhook load balancer
# Outgoing from EC2 to whitelisted IP's (GitHub webhook ip ranges), port 443
#
# Update asg.tf and concourse_worker as well!

# Webhooks security group for LB
resource "aws_security_group" "concourse_hooks" {
  count       = var.concourse_auth_alb_conf.enable_auth_alb == false ? 0 : 1
  name        = "${local.environment}-ConcourseHooks"
  description = "Concourse Incoming Webhooks to Web Nodes"
  vpc_id      = local.vpc.vpc_id
  tags        = merge(local.common_tags, { Name = local.name })

  lifecycle {
    create_before_destroy = true
  }
}

# Webhooks security group rule for LB incoming from whitelisted IP's (GitHub webhook ip ranges)
resource "aws_security_group_rule" "lb_hooks_https_in" {
  count             = var.concourse_auth_alb_conf.enable_auth_alb == false ? 0 : 1
  description       = "enable inbound webhook connectivity from whitelisted endpoints"
  type              = "ingress"
  protocol          = "tcp"
  from_port         = 443
  to_port           = 443
  security_group_id = aws_security_group.concourse_hooks[0].id
  cidr_blocks       = var.concourse_auth_alb_conf.auth_alb_hooks_ip_whitelist
}

# Webhooks security group rule for LB to Concourse web node(s)
resource "aws_security_group_rule" "lb_hooks_http_out" {
  count             = var.concourse_auth_alb_conf.enable_auth_alb == false ? 0 : 1
  description       = "enable outbound webhook connectivity from loadbalancer to EC2"
  type              = "egress"
  protocol          = "tcp"
  from_port         = var.concourse_web_port
  to_port           = var.concourse_web_port
  security_group_id = aws_security_group.concourse_hooks[0].id
  cidr_blocks       = ["0.0.0.0/0"]
}

# Webhooks security group for EC2
resource "aws_security_group" "concourse_hooks_ec2" {
  count       = var.concourse_auth_alb_conf.enable_auth_alb == false ? 0 : 1
  name        = "${local.environment}-ConcourseHooksEC2"
  description = "Concourse Incoming Webhooks to Web Nodes"
  vpc_id      = local.vpc.vpc_id
  tags        = merge(local.common_tags, { Name = local.name })

  lifecycle {
    create_before_destroy = true
  }
}

# Webhooks security group rule for EC2 incoming from webhook loadbalancer
resource "aws_security_group_rule" "lb_hooks_ec2_http_in" {
  count                    = var.concourse_auth_alb_conf.enable_auth_alb == false ? 0 : 1
  description              = "enable inbound webhook connectivity from loadbalancer"
  type                     = "ingress"
  protocol                 = "tcp"
  from_port                = var.concourse_web_port
  to_port                  = var.concourse_web_port
  security_group_id        = aws_security_group.concourse_hooks_ec2[0].id
  source_security_group_id = aws_security_group.concourse_hooks[0].id
}

# Webhooks security group rule for EC2 outgoing to whitelisted IP's (GitHub webhook ip ranges)
resource "aws_security_group_rule" "lb_hooks_ec2_http_out" {
  count             = var.concourse_auth_alb_conf.enable_auth_alb == false ? 0 : 1
  description       = "enable outbound webhook connectivity from EC2 web nodes"
  type              = "egress"
  protocol          = "tcp"
  from_port         = 443
  to_port           = 443
  security_group_id = aws_security_group.concourse_hooks_ec2[0].id
  cidr_blocks       = var.concourse_auth_alb_conf.auth_alb_hooks_ip_whitelist
}