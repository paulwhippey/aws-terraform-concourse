resource "aws_security_group" "allow_proxy" {
  name        = "allow_proxy"
  description = "Allow proxy inbound traffic"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "proxy from VPC"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [module.vpc.vpc_cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

data "template_cloudinit_config" "proxy_cloud_init" {
  gzip          = true
  base64_encode = true

  part {
    filename     = "init.cfg"
    content_type = "text/cloud-config"
    content      = templatefile("${path.module}/templates/proxy/cloud-init.cfg", {})
  }

  part {
    content_type = "text/x-shellscript"
    content      = templatefile("${path.module}/templates/proxy/cloud-init.sh", {})
  }
}


resource "aws_instance" "external_proxy" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t3.small"
  key_name               = var.ec2_key_name
  subnet_id              = module.vpc.public_subnets[0]
  vpc_security_group_ids = [aws_security_group.allow_proxy.id]
  user_data              = data.template_cloudinit_config.proxy_cloud_init.rendered
  tags                   = merge(var.tags, { Name = "egress-proxy" })
}
