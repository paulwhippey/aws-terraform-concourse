variable "region" {
  default = ""
}

variable "project_name" {
  description = "The project / repo name for use in resource naming / tags"
  type        = string
  default     = "cicd"
}

variable "project_owner" {
  description = "The name of the project owner, for use in tagging"
  type        = string
  default     = "OPS"
}

variable "project_team" {
  description = "The name of the project team, for use in tagging"
  type        = string
  default     = "OPS"
}

variable "whitelist_cidr_blocks" {
  description = "Used as the whitelisted range for accessing the External Load Balancer for Concourse"
  type        = list(string)
  default = [
    "0.0.0.0/0"
  ]
}

variable "ami_id" {
  description = "AMI ID to use for launching Concourse Instances"
  type        = string
  default     = "ami-098828924dc89ea4a" // latest AL2 x86 AMI as of 15/02/21 #TODO this is out of date
}

variable "environment" {
  type        = string
  description = "Environment name for the deployment e.g mgmt"
}

variable "concourse_web_conf" {
  description = "Concourse Web config options"

  type = object({
    count                  = number
    max_instance_lifetime  = number
    instance_type          = string
    environment_override   = map(string)
    key_name               = string
    min_healthy_percentage = number
    asg_scaling_config = object({
      night = object({
        min_size         = number
        max_size         = number
        desired_capacity = number
        time             = string
      })
      day = object({
        min_size         = number
        max_size         = number
        desired_capacity = number
        time             = string
      })
    })
    ebs_volume = object({
      type = string
      iops = number
      size = number
    })
  })

  default = {
    instance_type          = "t2.2xlarge"
    max_instance_lifetime  = 60 * 60 * 24 * 7
    count                  = 1
    environment_override   = {}
    key_name               = null
    min_healthy_percentage = 0
    asg_scaling_config = {
      night = {
        min_size         = 1
        max_size         = 3
        desired_capacity = 1
        time             = "0 19 * * 1-5"
      }
      day = {
        min_size         = 1
        max_size         = 3
        desired_capacity = 1
        time             = "0 7 * * 1-5"
      }
    }
    ebs_volume = {
      type = "gp3"
      iops = 3000
      size = 40
    }
  }
}

variable "concourse_worker_conf" {
  description = "Concourse Worker config options"
  type = object({
    instance_iam_role      = string
    worker_assume_ci_roles = list(string)
    instance_type          = string
    count                  = number
    environment_override   = map(string)
    garden_network_pool    = string
    garden_max_containers  = string
    log_level              = string
    key_name               = string
    min_healthy_percentage = number
    asg_scaling_config = object({
      night = object({
        min_size         = number
        max_size         = number
        desired_capacity = number
        time             = string
      })
      day = object({
        min_size         = number
        max_size         = number
        desired_capacity = number
        time             = string
      })
    })
    ebs_volume = object({
      type = string
      iops = number
      size = number
    })
  })
  default = {
    instance_iam_role      = null
    worker_assume_ci_roles = null
    instance_type          = "t2.2xlarge"
    count                  = 3
    environment_override   = {}
    garden_network_pool    = "172.16.0.0/21"
    garden_max_containers  = "350"
    log_level              = "error"
    key_name               = null
    min_healthy_percentage = 0
    asg_scaling_config = {
      night = {
        min_size         = 1
        max_size         = 1
        desired_capacity = 1
        time             = "0 19 * * 1-5"
      }
      day = {
        min_size         = 1
        max_size         = 3
        desired_capacity = 1
        time             = "0 7 * * 1-5"
      }
    }
    ebs_volume = {
      type = "gp3"
      iops = 3000
      size = 100
    }
  }
}

variable "concourse_worker_cpu_tracked_scaling_target" {
  description = "(Optional) The average CPU value that autoscaling will endeavour to maintain the worker pool at."
  type        = number
  default     = 50.0
}

variable "concourse_db_use_serverless" {
  description = "(Optional) Flag to indicate to use the serverless configuration rather than the provisioned."
  type        = bool
  default     = false
}

variable "concourse_db_conf" {
  description = "(Optional) database configuration options for database creation"

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
    engine_version          = "10.11"
    backup_retention_period = 14
    preferred_backup_window = "01:00-03:00"
    skip_final_snapshot     = false
  }
}

variable "concourse_db_serverless_conf" {
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

variable "rds_deletion_protection" {
  description = "(Optional) Enable deletion protection for RDS."
  type        = bool
  default     = false
}

variable "create_database" {
  description = "(Optional) Flag to indicate if new database needs to be created."
  type        = bool
  default     = true
}

variable "existing_database_config" {
  description = "(Optional) Configuration of existing database for Concourse to use"
  type = object({
    endpoint          = string
    db_name           = string
    user              = string
    password          = string
    security_group_id = string
  })
  default = {
    endpoint          = null
    db_name           = null
    user              = null
    password          = null
    security_group_id = null
  }
}

variable "cidr" {
  description = "The CIDR ranges used for the deployed subnets"

  type = object({
    vpc     = string
    private = list(string)
    public  = list(string)
  })

  default = {
    vpc     = "10.0.0.0/16"
    private = ["10.0.0.0/24", "10.0.1.0/24", "10.0.2.0/24"]
    public  = ["10.0.100.0/24", "10.0.101.0/24", "10.0.102.0/24"]
  }
}

variable "vpc_name" {
  description = "The name to use for the VPC"
  type        = string
  default     = "cicd"
}

variable "create_vpc" {
  description = "(Optional) Flag to indicate if new VPC needs to be created."
  type        = bool
  default     = true
}

variable "vpc_id" {
  description = "(Optional) The id of the VPC to create resources in. Requires `create_vpc` to be `false`."
  type        = string
  default     = null
}

variable "public_subnets" {
  description = "(Optional) List of public subnet IDs and CIDRs."
  type = object({
    ids         = list(string)
    cidr_blocks = list(string)
  })
  default = {
    ids         = []
    cidr_blocks = []
  }
}

variable "private_subnets" {
  description = "(Optional) List of private subnet IDs and CIDRs."
  type = object({
    ids         = list(string)
    cidr_blocks = list(string)
  })
  default = {
    ids         = []
    cidr_blocks = []
  }
}

variable "vpc_endpoint_s3_pl_id" {
  description = "(Optional) The prefix list for the S3 VPC endpoint."
  type        = string
  default     = ""
}

variable "vpc_endpoint_dynamodb_pl_id" {
  description = "(Optional) The prefix list for the DynamoDB VPC endpoint."
  type        = string
  default     = ""
}

variable "root_domain" {
  description = "The root DNS domain on which to base the deployment"
  type        = string
  default     = "cicd.aws"
}

variable "is_internal" {
  description = "(Optional) If `true` then the 'external' load balancer is deployed as internal. Used in scenarios where routing to Concourse is over a VPN into AWS, instead of via internet gateway. If set to `true` then both public and private hosted zones with the `var.root_domain` will need to exist (public for validating ACM certificate, private for routing)."
  type        = bool
  default     = false
}

variable "concourse_version" {
  type        = string
  description = "The Concourse version to deploy"
  default     = "7.2.0"
}

variable "concourse_web_port" {
  type        = number
  description = "TCP port that Concourse web service listens on. Do not change."
  default     = 8080
}

variable "concourse_sec" {
  description = "Concourse Security Config"

  type = object({
    concourse_username                     = string
    concourse_password                     = string
    concourse_auth_duration                = string
    concourse_db_username                  = string
    concourse_db_password                  = string
    session_signing_key_public_secret_arn  = string
    session_signing_key_private_secret_arn = string
    tsa_host_key_private_secret_arn        = string
    tsa_host_key_public_secret_arn         = string
    worker_key_private_secret_arn          = string
    worker_key_public_secret_arn           = string
  })

  default = {
    concourse_username                     = "concourseadmin"
    concourse_password                     = "concoursePassword123!"
    concourse_auth_duration                = "12h"
    concourse_db_username                  = "concourseadmin"
    concourse_db_password                  = "4dm1n15strator"
    session_signing_key_public_secret_arn  = "ARN_NOT_SET"
    session_signing_key_private_secret_arn = "ARN_NOT_SET"
    tsa_host_key_private_secret_arn        = "ARN_NOT_SET"
    tsa_host_key_public_secret_arn         = "ARN_NOT_SET"
    worker_key_private_secret_arn          = "ARN_NOT_SET"
    worker_key_public_secret_arn           = "ARN_NOT_SET"
  }
}

variable "concourse_saml_conf" {
  description = "Concourse SAML config for e.g. Okta"

  type = object({
    enable_saml                    = bool
    display_name                   = string
    url                            = string
    ca_cert                        = string
    issuer                         = string
    concourse_main_team_saml_group = string
    concourse_saml_username_attr   = string
    concourse_saml_email_attr      = string
    concourse_saml_groups_attr     = string
  })

  default = {
    enable_saml                    = false
    display_name                   = null
    url                            = null
    ca_cert                        = null
    issuer                         = null
    concourse_main_team_saml_group = null
    concourse_saml_username_attr   = null
    concourse_saml_email_attr      = null
    concourse_saml_groups_attr     = null
  }
}

variable "github_oauth_conf" {
  description = "Concourse oAuth config for GitHub"

  type = object({
    enable_oauth                    = bool
    concourse_github_client_id      = string
    concourse_github_client_secret  = string
    concourse_main_team_github_org  = string
    concourse_main_team_github_team = string
    concourse_main_team_github_user = string
  })

  default = {
    enable_oauth                    = false
    concourse_github_client_id      = null # AWS Secrets Manager Path or ARN must be supplied here
    concourse_github_client_secret  = null # AWS Secrets Manager Path or ARN must be supplied here
    concourse_main_team_github_org  = null
    concourse_main_team_github_team = null
    concourse_main_team_github_user = null
  }
}

variable "gitlab_oauth_conf" {
  description = "Concourse oAuth config for GitLab"

  type = object({
    enable_oauth                     = bool
    concourse_gitlab_client_id       = string
    concourse_gitlab_client_secret   = string
    concourse_main_team_gitlab_group = string
    concourse_main_team_gitlab_user  = string
  })

  default = {
    enable_oauth                     = false
    concourse_gitlab_client_id       = null # AWS Secrets Manager Path or ARN must be supplied here
    concourse_gitlab_client_secret   = null # AWS Secrets Manager Path or ARN must be supplied here
    concourse_main_team_gitlab_group = null
    concourse_main_team_gitlab_user  = null
  }
}

variable "concourse_teams_conf" {
  description = "Concourse teams config"
  type        = map(any)
  default     = {}
}

variable "concourse_internal_allowed_principals" {
  description = "A list of AWS principals that are allowed to reach Concourse via its internal load balancer"
  type        = list(string)
  default     = []
}

variable "proxy" {
  description = "(Optional) Configure HTTP, HTTPS, and NO_PROXY"
  type = object({
    http_proxy  = string
    https_proxy = string
    no_proxy    = string
  })
  default = {
    http_proxy  = null
    https_proxy = null
    no_proxy    = null
  }
}

variable "tags" {
  description = "(Optional) Tags to apply to aws resources"
  type        = map(string)
  default     = {}
}

variable "allow_worker_access_to_ecr" {
  description = "(Optional) Flag to indicate if the AmazonEC2ContainerRegistryReadOnly policy should be attached to the worker."
  type        = bool
  default     = false
}

### Authenticating Load Balancer Configuration ###

# Added to enable Concourse to be protected behind an authenticating ALB
variable "concourse_auth_alb_conf" {
  description = "Concourse authenticating ALB config"

  type = object({
    enable_auth_alb             = bool
    auth_alb_idp_ip_whitelist   = list(string)
    auth_alb_hooks_ip_whitelist = list(string)
    enable_aws_sso              = bool
    aws_sso_idp_name            = string
  })

  default = {
    enable_auth_alb             = false
    auth_alb_idp_ip_whitelist   = null
    auth_alb_hooks_ip_whitelist = null
    enable_aws_sso              = false
    aws_sso_idp_name            = null
  }
}
