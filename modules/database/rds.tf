resource "aws_db_subnet_group" "cluster" {
  subnet_ids = var.vpc.subnets
}

resource "aws_kms_key" "aurora" {
  enable_key_rotation     = true
  deletion_window_in_days = 7
  tags                    = merge(var.tags, { Name = "${var.name}-db-key", ProtectsSensitiveData = true })
}

resource "aws_kms_alias" "aurora" {
  name          = "alias/${var.environment}-${var.name}-db-key"
  target_key_id = aws_kms_key.aurora.key_id
}

resource "aws_rds_cluster" "cluster" {
  cluster_identifier        = "${var.name}-${var.environment}"
  engine                    = var.use_serverless ? var.serverless.engine : var.database.engine
  engine_mode               = "provisioned"
  engine_version            = var.use_serverless ? var.serverless.engine_version : var.database.engine_version
  availability_zones        = local.zone_names
  database_name             = var.name
  master_username           = var.database_credentials.username
  master_password           = var.database_credentials.password
  backup_retention_period   = 14
  preferred_backup_window   = var.use_serverless ? var.serverless.preferred_backup_window : var.database.preferred_backup_window
  apply_immediately         = true
  db_subnet_group_name      = aws_db_subnet_group.cluster.id
  final_snapshot_identifier = "${var.name}-final-snapshot"
  skip_final_snapshot       = var.use_serverless ? var.serverless.skip_final_snapshot : var.database.skip_final_snapshot
  storage_encrypted         = var.encrypt_storage
  kms_key_id                = aws_kms_key.aurora.arn
  vpc_security_group_ids    = [aws_security_group.db.id]
  tags                      = merge(var.tags, { Name = "${var.name}-db" })
  deletion_protection       = var.deletion_protection

  dynamic "serverlessv2_scaling_configuration" {
    for_each = var.use_serverless == true ? [true] : []
    content {
      min_capacity = var.serverless.serverless_capacity_min
      max_capacity = var.serverless.serverless_capacity_max
    }
  }

  lifecycle {
    ignore_changes = [
      engine_version,
      snapshot_identifier,
      availability_zones, # See PR for explanation: https://github.com/IDPdigital/terraform-aws-concourse/pull/39
    ]
  }
}

resource "aws_rds_cluster_instance" "cluster" {
  count              = var.use_serverless ? var.serverless.db_count : var.database.db_count
  identifier_prefix  = "${var.name}-${local.zone_names[count.index]}-"
  engine             = aws_rds_cluster.cluster.engine
  engine_version     = aws_rds_cluster.cluster.engine_version
  availability_zone  = local.zone_names[count.index]
  cluster_identifier = aws_rds_cluster.cluster.id
  instance_class     = var.use_serverless ? "db.serverless" : var.database.instance_type
  tags               = var.tags

  lifecycle {
    create_before_destroy = true
  }
}
