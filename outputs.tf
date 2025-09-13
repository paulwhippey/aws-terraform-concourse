output "vpc_id" {
  value = local.vpc.vpc_id
}

output "concourse_web_dns" {
  value = "https://${local.fqdn}"
}

output "web_url" {
  value = aws_route53_record.concourse_web_lb.fqdn

}

output "security_groups" {
  value = {
    concourse_web                   = aws_security_group.concourse_web.id
    concourse_worker                = aws_security_group.concourse_worker.id
    concourse_load_balancer         = aws_security_group.concourse_lb.id
    concourse_load_balancer_clients = aws_security_group.concourse_lb_clients.id
    concourse_vpc_endpoints         = aws_security_group.concourse_vpc_endpoints.id
    concourse_database              = local.database.security_group_id
  }
}

output "manage_web_ip_address_access_url" {
  value = aws_lambda_function_url.manage_web_ip_address_access_add.function_url
}
