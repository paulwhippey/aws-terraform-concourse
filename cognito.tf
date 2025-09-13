### Authenticating Load Balancer Cognito Configuration ###

resource "aws_cognito_user_pool" "pool" {
  count = var.concourse_auth_alb_conf.enable_auth_alb == false ? 0 : 1
  name  = "${local.environment}-${local.account}-concourse-user-pool"
  admin_create_user_config {
    allow_admin_create_user_only = true
  }
  account_recovery_setting {
    recovery_mechanism {
      name     = "verified_email"
      priority = 1
    }
  }
  username_attributes = ["email"]
  tags                = merge(local.common_tags)
}

resource "aws_cognito_user_pool_client" "client" {
  count               = var.concourse_auth_alb_conf.enable_auth_alb == false ? 0 : 1
  name                = "${local.environment}-${local.account}-concourse-user-pool-client"
  user_pool_id        = aws_cognito_user_pool.pool[0].id
  generate_secret     = true
  allowed_oauth_flows = ["code"]
  callback_urls = [
    "https://${local.backend_alias}/oauth2/idpresponse",
    "https://${local.backend_alias}/",
  ]
  allowed_oauth_scopes                 = ["email", "openid"]
  allowed_oauth_flows_user_pool_client = true
  # Dynamically add the Cognito SSO provider to the Cognito config
  # condition ? true_val : false_val
  supported_identity_providers = var.concourse_auth_alb_conf.enable_aws_sso == false ? ["COGNITO"] : ["COGNITO", var.concourse_auth_alb_conf.aws_sso_idp_name]
  explicit_auth_flows = [
    "ALLOW_CUSTOM_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH",
    "ALLOW_USER_SRP_AUTH",
  ]
  # Added, or TF will try to re-create this client every time an apply is run
  access_token_validity = 60
  id_token_validity     = 60
  token_validity_units {
    access_token  = "minutes"
    id_token      = "minutes"
    refresh_token = "days"
  }
}

resource "aws_cognito_user_pool_domain" "domain" {
  count        = var.concourse_auth_alb_conf.enable_auth_alb == false ? 0 : 1
  domain       = "${local.environment}-${local.account}-concourse-user-pool-domain"
  user_pool_id = aws_cognito_user_pool.pool[0].id
}
