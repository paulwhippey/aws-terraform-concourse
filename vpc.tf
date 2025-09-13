module "vpc" {
  count = var.create_vpc ? 1 : 0

  enable_ipv6                 = true
  public_subnet_ipv6_prefixes = slice([0, 1, 2], 0, length(var.cidr.public))

  source  = "terraform-aws-modules/vpc/aws"
  version = "2.78.0"

  name = join(".", [var.vpc_name, local.environment])
  cidr = var.cidr.vpc

  azs             = local.zone_names
  private_subnets = var.cidr.private
  public_subnets  = var.cidr.public

  enable_nat_gateway = true
  create_igw         = true

  enable_public_s3_endpoint      = true
  enable_s3_endpoint             = true
  enable_dynamodb_endpoint       = true
  enable_ssm_endpoint            = true
  enable_ssmmessages_endpoint    = true
  enable_ec2messages_endpoint    = true
  enable_secretsmanager_endpoint = true

  ssm_endpoint_security_group_ids            = [aws_security_group.concourse_vpc_endpoints.id]
  ssmmessages_endpoint_security_group_ids    = [aws_security_group.concourse_vpc_endpoints.id]
  ec2messages_endpoint_security_group_ids    = [aws_security_group.concourse_vpc_endpoints.id]
  secretsmanager_endpoint_security_group_ids = [aws_security_group.concourse_vpc_endpoints.id]

  tags = {
    Terraform   = "true"
    Environment = local.environment
  }
}

data "aws_vpc" "vpc" {
  count = !var.create_vpc ? 1 : 0
  id    = var.vpc_id
}

locals {
  vpc = var.create_vpc ? {
    vpc_id                      = module.vpc[0].vpc_id
    private_subnets             = module.vpc[0].private_subnets
    private_subnets_cidr_blocks = module.vpc[0].private_subnets_cidr_blocks
    public_subnets              = module.vpc[0].public_subnets
    vpc_endpoint_s3_pl_id       = module.vpc[0].vpc_endpoint_s3_pl_id
    vpc_endpoint_dynamodb_pl_id = module.vpc[0].vpc_endpoint_dynamodb_pl_id
    } : {
    vpc_id                      = data.aws_vpc.vpc[0].id
    private_subnets             = var.private_subnets.ids
    private_subnets_cidr_blocks = var.private_subnets.cidr_blocks
    public_subnets              = var.public_subnets.ids
    vpc_endpoint_s3_pl_id       = var.vpc_endpoint_s3_pl_id
    vpc_endpoint_dynamodb_pl_id = var.vpc_endpoint_dynamodb_pl_id
  }
}

//resource "aws_route" "concourse_ui_to_client" {
//  count                  = length(local.route_table_cidr_combinations)
//  route_table_id         = local.route_table_cidr_combinations[count.index].rtb_id
//  destination_cidr_block = local.route_table_cidr_combinations[count.index].cidr
//  nat_gateway_id         = local.vpc.natgw_ids[count.index % local.zone_count]
//}
