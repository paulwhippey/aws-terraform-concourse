locals {

  saml_cert_path = "/etc/concourse/saml.cert"

  //  logger_bootstrap_file = templatefile(
  //  "${path.module}/files/concourse_web/logger_bootstrap.sh",
  //  {
  //    cloudwatch_agent_config_ssm_parameter = aws_ssm_parameter.cloudwatch_agent_config_web.name
  //    https_proxy                           = var.proxy.https_proxy
  //  }
  //  )

  web_service_env_vars = merge(
    {
      CONCOURSE_CLUSTER_NAME  = local.name
      CONCOURSE_EXTERNAL_URL  = "https://${local.fqdn}"
      CONCOURSE_AUTH_DURATION = var.concourse_sec.concourse_auth_duration

      CONCOURSE_POSTGRES_DATABASE = local.database.database_name
      CONCOURSE_POSTGRES_HOST     = local.database.endpoint

      CONCOURSE_SESSION_SIGNING_KEY = "/etc/concourse/session_signing_key"
      CONCOURSE_TSA_AUTHORIZED_KEYS = "/etc/concourse/authorized_worker_keys"
      CONCOURSE_TSA_HOST_KEY        = "/etc/concourse/tsa_host_key"
      CONCOURSE_TSA_LOG_LEVEL       = "error"
      CONCOURSE_LOG_LEVEL           = "error"

      #TODO: Setup Monitoring !10
      CONCOURSE_PROMETHEUS_BIND_IP   = "0.0.0.0"
      CONCOURSE_PROMETHEUS_BIND_PORT = 9090

      CONCOURSE_AWS_SECRETSMANAGER_REGION                   = data.aws_region.current.name
      CONCOURSE_AWS_SECRETSMANAGER_PIPELINE_SECRET_TEMPLATE = "/concourse/{{.Team}}/{{.Pipeline}}/{{.Secret}}"
      CONCOURSE_AWS_SECRETSMANAGER_TEAM_SECRET_TEMPLATE     = "/concourse/{{.Team}}/{{.Secret}}"
      CONCOURSE_SECRET_CACHE_DURATION                       = "1m"

      CONCOURSE_METRICS_HOST_NAME     = local.name
      CONCOURSE_CAPTURE_ERROR_METRICS = true

      #TODO: Audit logging
      CONCOURSE_ENABLE_BUILD_AUDITING     = true
      CONCOURSE_ENABLE_CONTAINER_AUDITING = true
      CONCOURSE_ENABLE_JOB_AUDITING       = true
      CONCOURSE_ENABLE_PIPELINE_AUDITING  = true
      CONCOURSE_ENABLE_RESOURCE_AUDITING  = true
      CONCOURSE_ENABLE_SYSTEM_AUDITING    = true
      CONCOURSE_ENABLE_TEAM_AUDITING      = true
      CONCOURSE_ENABLE_WORKER_AUDITING    = true
      CONCOURSE_ENABLE_VOLUME_AUDITING    = true

      CONCOURSE_CONTAINER_PLACEMENT_STRATEGY = "random"
    },
    var.proxy.http_proxy != null ? { HTTP_PROXY = var.proxy.http_proxy, http_proxy = var.proxy.http_proxy } : {},
    var.proxy.https_proxy != null ? { HTTPS_PROXY = var.proxy.https_proxy, https_proxy = var.proxy.https_proxy } : {},
    var.proxy.no_proxy != null ? { NO_PROXY = var.proxy.no_proxy, no_proxy = var.proxy.no_proxy } : {},
    var.concourse_saml_conf.enable_saml ? {
      # SAML Auth
      CONCOURSE_SAML_DISPLAY_NAME  = var.concourse_saml_conf.display_name
      CONCOURSE_SAML_SSO_URL       = var.concourse_saml_conf.url
      CONCOURSE_SAML_CA_CERT       = local.saml_cert_path
      CONCOURSE_SAML_SSO_ISSUER    = var.concourse_saml_conf.issuer
      CONCOURSE_SAML_USERNAME_ATTR = var.concourse_saml_conf.concourse_saml_username_attr
      CONCOURSE_SAML_EMAIL_ATTR    = var.concourse_saml_conf.concourse_saml_email_attr
      CONCOURSE_SAML_GROUPS_ATTR   = var.concourse_saml_conf.concourse_saml_groups_attr
    } : {},
  )

  web_systemd_file = templatefile(
    "${path.module}/files/concourse_web/web_systemd",
    {
      environment_vars = local.web_service_env_vars
    }
  )

  web_upstart_file = templatefile(
    "${path.module}/files/concourse_web/web_upstart",
    {
      environment_vars = local.web_service_env_vars
    }
  )

  web_bootstrap_file = templatefile(
    "${path.module}/files/concourse_web/web_bootstrap.sh",
    {
      aws_default_region                     = data.aws_region.current.name
      concourse_version                      = var.concourse_version
      concourse_username                     = var.concourse_sec.concourse_username
      concourse_password                     = var.concourse_sec.concourse_password
      concourse_db_username                  = var.concourse_sec.concourse_db_username
      concourse_db_password                  = var.concourse_sec.concourse_db_password
      session_signing_key_public_secret_arn  = var.concourse_sec.session_signing_key_public_secret_arn
      session_signing_key_private_secret_arn = var.concourse_sec.session_signing_key_private_secret_arn
      tsa_host_key_private_secret_arn        = var.concourse_sec.tsa_host_key_private_secret_arn
      tsa_host_key_public_secret_arn         = var.concourse_sec.tsa_host_key_public_secret_arn
      worker_key_private_secret_arn          = var.concourse_sec.worker_key_private_secret_arn
      worker_key_public_secret_arn           = var.concourse_sec.worker_key_public_secret_arn
      enable_saml                            = var.concourse_saml_conf.enable_saml
      concourse_main_team_saml_group         = var.concourse_saml_conf.concourse_main_team_saml_group
      enable_github_oauth                    = var.github_oauth_conf.enable_oauth
      concourse_github_client_id             = var.github_oauth_conf.concourse_github_client_id
      concourse_github_client_secret         = var.github_oauth_conf.concourse_github_client_secret
      concourse_main_team_github_org         = var.github_oauth_conf.concourse_main_team_github_org
      concourse_main_team_github_team        = var.github_oauth_conf.concourse_main_team_github_team
      concourse_main_team_github_user        = var.github_oauth_conf.concourse_main_team_github_user
      enable_gitlab_oauth                    = var.gitlab_oauth_conf.enable_oauth
      concourse_gitlab_client_id             = var.gitlab_oauth_conf.concourse_gitlab_client_id
      concourse_gitlab_client_secret         = var.gitlab_oauth_conf.concourse_gitlab_client_secret
      concourse_main_team_gitlab_group       = var.gitlab_oauth_conf.concourse_main_team_gitlab_group
      concourse_main_team_gitlab_user        = var.gitlab_oauth_conf.concourse_main_team_gitlab_user
    }
  )

  teams = templatefile(
    "${path.module}/files/concourse_web/teams.sh",
    {
      aws_default_region = data.aws_region.current.name
      target             = "aws-concourse"
      concourse_username = var.concourse_sec.concourse_username
      concourse_password = var.concourse_sec.concourse_password
      concourse_web_port = tostring(var.concourse_web_port)
    }
  )

  web_logging = file(
    "${path.module}/files/concourse_web/cloudwatch_agent_config.json"
  )
}

data "template_cloudinit_config" "web_bootstrap" {
  gzip          = true
  base64_encode = true

  part {
    content_type = "text/cloud-config"
    content      = templatefile("${path.module}/files/common/configure_proxy.cfg", { proxy_config = var.proxy })
  }

  part {
    content_type = "text/x-shellscript"
    content      = templatefile("${path.module}/files/common/configure_proxy.sh", { proxy_config = var.proxy })
  }

  part {
    content_type = "text/cloud-config"
    content      = "package_update: true"
  }

  part {
    content_type = "text/cloud-config"
    content      = "package_upgrade: true"
  }

  part {
    content_type = "text/cloud-config"
    content      = <<EOF
packages:
  - aws-cli
  - jq
  - amazon-cloudwatch-agent
EOF
  }

  part {
    content_type = "text/cloud-config"
    content      = <<EOF
write_files:
  - encoding: b64
    content: ${base64encode(local.web_upstart_file)}
    owner: root:root
    path: /etc/init/concourse-web.conf
    permissions: '0644'
  - encoding: b64
    content: ${base64encode(local.web_systemd_file)}
    owner: root:root
    path: /etc/systemd/system/concourse-web.service
    permissions: '0644'
  - encoding: b64
    content: ${base64encode(local.web_logging)}
    owner: root:root
    path: /opt/aws/amazon-cloudwatch-agent/bin/config.json
    permissions: '0644'
%{if var.concourse_saml_conf.enable_saml~}
  - encoding: b64
    content: ${base64encode(var.concourse_saml_conf.ca_cert)}
    owner: root:root
    path: ${local.saml_cert_path}
    permissions: '0600'
%{endif~}
%{for team in keys(var.concourse_teams_conf)~}
  - encoding: b64
    content: ${base64encode(lookup(var.concourse_teams_conf, team))}
    owner: root:root
    path: /root/teams/${team}/team.yml
    permissions: '0600'
%{endfor~}
EOF
  }

  part {
    content_type = "text/x-shellscript"
    content      = <<EOF
#!/bin/bash
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -s -c file:/opt/aws/amazon-cloudwatch-agent/bin/config.json
EOF
  }

  part {
    content_type = "text/x-shellscript"
    content      = local.web_bootstrap_file
  }

  part {
    content_type = "text/x-shellscript"
    content      = local.teams
  }
}
