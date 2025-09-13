resource "aws_security_group" "database" {
  name        = "allow_postgres"
  description = "Allow postgres inbound traffic"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "postgresql from VPC"
    from_port   = 5432
    to_port     = 5432
    protocol    = "TCP"
    cidr_blocks = [module.vpc.vpc_cidr_block]
  }

  ingress {
    description = "postgresql from VPC"
    from_port   = 22
    to_port     = 22
    protocol    = "TCP"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = var.tags
}

resource "random_string" "master_password" {
  length  = 32
  special = false
}

locals {
  user_data = templatefile("${path.module}/templates/database/cloud-init.cfg", {})
  user_data_script = templatefile("${path.module}/templates/database/cloud-init.sh", {
    db_master_pass = random_string.master_password.result
    db_master_user = var.postgres_master_user
  })
}

data "template_cloudinit_config" "database_cloud_init" {
  gzip          = true
  base64_encode = true

  part {
    filename     = "init.cfg"
    content_type = "text/cloud-config"
    content      = local.user_data
  }

  part {
    content_type = "text/x-shellscript"
    content      = local.user_data_script
  }
}

resource "aws_instance" "external_database" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t3.small"
  key_name               = var.ec2_key_name
  subnet_id              = module.vpc.public_subnets[0]
  vpc_security_group_ids = [aws_security_group.database.id]
  user_data              = data.template_cloudinit_config.database_cloud_init.rendered
  tags                   = merge(var.tags, { Name = "database" })
}
