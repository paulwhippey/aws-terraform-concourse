data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
data "aws_availability_zones" "current" {}

terraform {
  required_providers {
    random = "~> 2.0"
    # AWS provider bumped to 3.45.0 as earlier versions have a Cognito user pool settings bug: https://github.com/hashicorp/terraform-provider-aws/issues/17228
    aws = "~> 4.27.0"
  }
}
