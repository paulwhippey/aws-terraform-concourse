variable "allowed_security_groups" {
  description = "The ids of the security groups to allow db access from"
  type        = list(string)
}

variable "database_credentials" {
  description = "Credentials to set for database master user"

  type = object({
    username = string,
    password = string,
  })
}

variable "name" {
  description = "Common name. Used as part of resource names"
  type        = string
}

variable "vpc" {
  description = "VPC config, including VPC ID and a list of subnets"
  type = object({
    id      = string
    subnets = list(string)
  })
}

variable "aws_availability_zones_names" {
  description = "(Optional) List of AWS availability zone names to use. If unset, then all available availability zones will be usable by RDS (dependant on number of instances)"
  type        = list(string)
  default     = null
}

variable "environment" {
  description = "(Optional) Resource environment tag (i.e. dev, stage, prod). Used in resource names"
  type        = string
  default     = "test"
}

variable "use_serverless" {
  description = "(Optional) Flag to indicate to use the serverless configuration rather than the provisioned."
  type        = bool
  default     = false
}

variable "deletion_protection" {
  description = "(Optional) Enable deletion protection."
  type        = bool
  default     = false
}

variable "database" {
  description = "(Optional) Database configuration options"

  type = object({
    instance_type           = string
    db_count                = number
    engine                  = string
    engine_version          = string
    backup_retention_period = number
    preferred_backup_window = string
    skip_final_snapshot     = bool
  })

  default = {
    instance_type           = "db.t3.medium"
    db_count                = 1
    engine                  = "aurora-postgresql"
    engine_version          = "11.9"
    backup_retention_period = 14
    preferred_backup_window = "01:00-03:00"
    skip_final_snapshot     = false
  }
}

variable "serverless" {
  description = "(Optional) database configuration options for serverless database creation"

  type = object({
    db_count                = number
    engine                  = string
    engine_version          = string
    backup_retention_period = number
    preferred_backup_window = string
    skip_final_snapshot     = bool
    serverless_capacity_min = number
    serverless_capacity_max = number
  })

  default = {
    db_count                = 1
    engine                  = "aurora-postgresql"
    engine_version          = "14.3"
    backup_retention_period = 14
    preferred_backup_window = "01:00-03:00"
    skip_final_snapshot     = false
    serverless_capacity_min = 0.5
    serverless_capacity_max = 4.0
  }
}

variable "encrypt_storage" {
  type        = bool
  description = "(Optional) true/false value to set whether storage within the RDS Database should be encrypted"
  default     = true
}

variable "tags" {
  description = "Tags to apply to aws resources"
  type        = map(string)
  default     = {}
}
