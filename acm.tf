resource "aws_acm_certificate" "concourse_web_dl" {
  domain_name       = local.fqdn
  validation_method = "DNS"

  tags = local.common_tags
}

resource "aws_route53_record" "concourse_web_dl" {
  for_each = {
    for dvo in aws_acm_certificate.concourse_web_dl.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = data.aws_route53_zone.public.zone_id
}

resource "aws_acm_certificate_validation" "concourse_web_dl" {
  certificate_arn         = aws_acm_certificate.concourse_web_dl.arn
  validation_record_fqdns = [for record in aws_route53_record.concourse_web_dl : record.fqdn]
}

### Webhook Load balancer ###

# Webhooks LB related ACM certificate
resource "aws_acm_certificate" "concourse_hooks_dl" {
  count             = var.concourse_auth_alb_conf.enable_auth_alb == false ? 0 : 1
  domain_name       = local.fqdn_hooks
  validation_method = "DNS"

  tags = local.common_tags
}

# Webhooks LB Route 53 ACM records
resource "aws_route53_record" "concourse_hooks_dl" {

  #   for_each {
  #     for dvo in aws_acm_certificate.concourse_hooks_dl[0].domain_validation_options : dvo.domain_name => {
  #       name   = dvo.resource_record_name
  #       record = dvo.resource_record_value
  #       type   = dvo.resource_record_type
  #     }
  #   }

  #   allow_overwrite = true
  #   name            = each.value.name
  #   records         = [each.value.record]
  #   ttl             = 60
  #   type            = each.value.type
  #   zone_id         = data.aws_route53_zone.public.zone_id

  count           = var.concourse_auth_alb_conf.enable_auth_alb == false ? 0 : 1
  allow_overwrite = true
  name            = tolist(aws_acm_certificate.concourse_hooks_dl[0].domain_validation_options)[0].resource_record_name
  records         = [tolist(aws_acm_certificate.concourse_hooks_dl[0].domain_validation_options)[0].resource_record_value]
  ttl             = 60
  type            = tolist(aws_acm_certificate.concourse_hooks_dl[0].domain_validation_options)[0].resource_record_type
  zone_id         = data.aws_route53_zone.public.zone_id

}

# Webhooks LB certificate validation record
resource "aws_acm_certificate_validation" "concourse_hooks_dl" {
  count                   = var.concourse_auth_alb_conf.enable_auth_alb == false ? 0 : 1
  certificate_arn         = aws_acm_certificate.concourse_hooks_dl[0].arn
  validation_record_fqdns = [for record in aws_route53_record.concourse_hooks_dl : record.fqdn]
}
