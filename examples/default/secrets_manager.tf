resource "tls_private_key" "session_signing_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}
resource "aws_secretsmanager_secret" "session_signing_key_public" {
  name_prefix = "/concourse/cicd_session_signing_key_public_"
}
resource "aws_secretsmanager_secret_version" "session_signing_key_public" {
  secret_id     = aws_secretsmanager_secret.session_signing_key_public.id
  secret_string = tls_private_key.session_signing_key.public_key_openssh
}
resource "aws_secretsmanager_secret" "session_signing_key_private" {
  name_prefix = "/concourse/cicd_session_signing_key_private_"
}
resource "aws_secretsmanager_secret_version" "session_signing_key_private" {
  secret_id     = aws_secretsmanager_secret.session_signing_key_private.id
  secret_string = tls_private_key.session_signing_key.private_key_pem
}
resource "tls_private_key" "tsa_host_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}
resource "aws_secretsmanager_secret" "tsa_host_key_public" {
  name_prefix = "/concourse/cicd_tsa_host_key_public_"
}
resource "aws_secretsmanager_secret_version" "tsa_host_key_public" {
  secret_id     = aws_secretsmanager_secret.tsa_host_key_public.id
  secret_string = tls_private_key.tsa_host_key.public_key_openssh
}
resource "aws_secretsmanager_secret" "tsa_host_key_private" {
  name_prefix = "/concourse/cicd_tsa_host_key_private_"
}
resource "aws_secretsmanager_secret_version" "tsa_host_key_private" {
  secret_id     = aws_secretsmanager_secret.tsa_host_key_private.id
  secret_string = tls_private_key.tsa_host_key.private_key_pem
}
resource "tls_private_key" "worker_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}
resource "aws_secretsmanager_secret" "worker_key_public" {
  name_prefix = "/concourse/cicd_worker_key_public_"
}
resource "aws_secretsmanager_secret_version" "worker_key_public" {
  secret_id     = aws_secretsmanager_secret.worker_key_public.id
  secret_string = tls_private_key.worker_key.public_key_openssh
}
resource "aws_secretsmanager_secret" "worker_key_private" {
  name_prefix = "/concourse/cicd_worker_key_private_"
}
resource "aws_secretsmanager_secret_version" "worker_key_private" {
  secret_id     = aws_secretsmanager_secret.worker_key_private.id
  secret_string = tls_private_key.worker_key.private_key_pem
}
