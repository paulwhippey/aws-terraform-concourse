module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "2.78.0"

  name = join(".", ["cicd", local.environment])
  cidr = var.cidr.vpc

  azs             = data.aws_availability_zones.current.names
  private_subnets = var.cidr.private
  public_subnets  = var.cidr.public

  enable_nat_gateway = true
  create_igw         = true

  enable_public_s3_endpoint      = true
  enable_s3_endpoint             = true
  enable_dynamodb_endpoint       = true
  enable_ssm_endpoint            = false
  enable_ssmmessages_endpoint    = false
  enable_ec2messages_endpoint    = false
  enable_secretsmanager_endpoint = false

  tags = {
    Terraform   = "true"
    Environment = local.environment
  }
}

locals {
  environment = var.environment
}
