provider "aws" {
  region = var.region
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

  cidr = {
    vpc     = "10.2.0.0/16"
    private = ["10.2.0.0/24", "10.2.1.0/24", "10.2.2.0/24"]
    public  = ["10.2.100.0/24", "10.2.101.0/24", "10.2.102.0/24"]
  }

  concourse_db_conf = {
    instance_type           = "db.t3.medium"
    db_count                = 1
    engine                  = "aurora-postgresql"
    engine_version          = "11.9"
    backup_retention_period = 14
    preferred_backup_window = "01:00-03:00"
    skip_final_snapshot     = true
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
