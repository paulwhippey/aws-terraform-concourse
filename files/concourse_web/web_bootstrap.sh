#!/bin/bash

set -euxo pipefail

export AWS_DEFAULT_REGION=${aws_default_region}
export CONCOURSE_USER=${concourse_username}
export CONCOURSE_PASSWORD="${concourse_password}"

export PRIVATE_IP_ADDRESS=$(curl http://169.254.169.254/latest/meta-data/local-ipv4)

mkdir -p /etc/concourse

aws_get_secret() {
    aws secretsmanager get-secret-value \
        --secret-id $1 \
        --query SecretString \
        --output text 
}

# Obtain keys from AWS Secrets Manager
aws_get_secret ${session_signing_key_private_secret_arn} > /etc/concourse/session_signing_key
aws_get_secret ${session_signing_key_public_secret_arn}  > /etc/concourse/session_signing_key.pub
aws_get_secret ${tsa_host_key_private_secret_arn} > /etc/concourse/tsa_host_key
aws_get_secret ${tsa_host_key_public_secret_arn} > /etc/concourse/tsa_host_key.pub
aws_get_secret ${worker_key_private_secret_arn} > /etc/concourse/worker_key
aws_get_secret ${worker_key_public_secret_arn} > /etc/concourse/worker_key.pub
cp /etc/concourse/worker_key.pub /etc/concourse/authorized_worker_keys
chmod 0600 /etc/concourse/*

wget -q https://github.com/concourse/concourse/releases/download/v${concourse_version}/concourse-${concourse_version}-linux-amd64.tgz
tar -zxf concourse-*.tgz -C /usr/local

cat >> /etc/profile.d/concourse.sh << \EOF
  PATH="/usr/local/concourse/bin:$PATH"
EOF

source /etc/profile.d/concourse.sh

cat <<EOF >> /etc/systemd/system/concourse-web.env
CONCOURSE_POSTGRES_PASSWORD=${concourse_db_password}
CONCOURSE_POSTGRES_USER=${concourse_db_username}
CONCOURSE_USER=${concourse_username}
CONCOURSE_PASSWORD=${concourse_password}
CONCOURSE_ADD_LOCAL_USER=$CONCOURSE_USER:$CONCOURSE_PASSWORD
CONCOURSE_MAIN_TEAM_LOCAL_USER=$CONCOURSE_USER
CONCOURSE_PEER_ADDRESS=$PRIVATE_IP_ADDRESS
%{ if enable_saml ~}
CONCOURSE_MAIN_TEAM_SAML_GROUP="${concourse_main_team_saml_group}"
%{ endif ~}
%{ if enable_github_oauth ~}
CONCOURSE_GITHUB_CLIENT_ID=$(aws_get_secret ${concourse_github_client_id})
CONCOURSE_GITHUB_CLIENT_SECRET=$(aws_get_secret ${concourse_github_client_secret})
CONCOURSE_MAIN_TEAM_GITHUB_ORG="${concourse_main_team_github_org}"
CONCOURSE_MAIN_TEAM_GITHUB_TEAM="${concourse_main_team_github_team}"
CONCOURSE_MAIN_TEAM_GITHUB_USER="${concourse_main_team_github_user}"
%{ endif ~}
%{ if enable_gitlab_oauth ~}
CONCOURSE_GITLAB_CLIENT_ID=$(aws_get_secret ${concourse_gitlab_client_id})
CONCOURSE_GITLAB_CLIENT_SECRET=$(aws_get_secret ${concourse_gitlab_client_secret})
CONCOURSE_MAIN_TEAM_GITLAB_GROUP="${concourse_main_team_gitlab_group}"
CONCOURSE_MAIN_TEAM_GITLAB_USER="${concourse_main_team_gitlab_user}"
%{ endif ~}
EOF

echo `date +'%Y %b %d %H:%M:%S'` "Starting Concourse service"
if [[ "$(rpm -qf /sbin/init)" == upstart* ]];
then
    initctl start concourse-web
else
    systemctl enable concourse-web.service
    systemctl start concourse-web.service
    while ! $(systemctl is-active --quiet concourse-web.service); do
      sleep 5
    done
    echo `date +'%Y %b %d %H:%M:%S'` "Concourse service started"
fi
