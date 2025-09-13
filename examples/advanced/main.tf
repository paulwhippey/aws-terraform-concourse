provider "aws" {
  region = var.region
}

data "aws_availability_zones" "current" {}
data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_ami" "amazon_linux_2" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["*amzn2-ami-hvm*"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

# Used for supporting infra
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

module "concourse" {
  source = "../../"

  region        = var.region
  project_owner = "testing"
  project_team  = "kitchen"
  ami_id        = data.aws_ami.amazon_linux_2.id

  create_vpc                  = false
  vpc_id                      = module.vpc.vpc_id
  vpc_endpoint_s3_pl_id       = module.vpc.vpc_endpoint_s3_pl_id
  vpc_endpoint_dynamodb_pl_id = module.vpc.vpc_endpoint_dynamodb_pl_id
  public_subnets = {
    ids         = module.vpc.public_subnets
    cidr_blocks = module.vpc.public_subnets
  }
  private_subnets = {
    ids         = module.vpc.private_subnets
    cidr_blocks = module.vpc.private_subnets_cidr_blocks
  }

  proxy = {
    http_proxy  = "http://${aws_instance.external_proxy.private_ip}:3128"
    https_proxy = "http://${aws_instance.external_proxy.private_ip}:3128"
    no_proxy    = "localhost,169.254.169.254,127.0.0.1"
  }

  create_database = false

  existing_database_config = {
    endpoint          = aws_instance.external_database.private_ip
    db_name           = var.concourse_credential.db.username
    user              = var.concourse_credential.db.username
    password          = var.concourse_credential.db.password
    security_group_id = aws_security_group.database.id
  }

  concourse_sec = {
    concourse_username                     = var.concourse_credential.web.username
    concourse_password                     = var.concourse_credential.web.password
    concourse_auth_duration                = "24h"
    concourse_db_username                  = var.concourse_credential.db.username
    concourse_db_password                  = var.concourse_credential.db.password
    session_signing_key_public_secret_arn  = aws_secretsmanager_secret_version.session_signing_key_public.arn
    session_signing_key_private_secret_arn = aws_secretsmanager_secret_version.session_signing_key_private.arn
    tsa_host_key_private_secret_arn        = aws_secretsmanager_secret_version.tsa_host_key_private.arn
    tsa_host_key_public_secret_arn         = aws_secretsmanager_secret_version.tsa_host_key_public.arn
    worker_key_private_secret_arn          = aws_secretsmanager_secret_version.worker_key_private.arn
    worker_key_public_secret_arn           = aws_secretsmanager_secret_version.worker_key_public.arn
  }

  root_domain = var.root_domain
}
