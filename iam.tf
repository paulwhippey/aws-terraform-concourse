resource "aws_iam_role" "concourse_web" {
  name               = "${local.environment}-concourse-web"
  assume_role_policy = data.aws_iam_policy_document.concourse_web.json

  tags = merge(
    local.common_tags,
    { Name = "${local.environment}-concourse-web" }
  )
}

resource "aws_iam_role" "concourse_worker" {
  count = var.concourse_worker_conf.instance_iam_role == null ? 1 : 0
  name  = "${local.environment}-concourse-worker"

  tags = merge(
    local.common_tags,
    { Name = "${local.environment}-concourse-worker" }
  )
  assume_role_policy = data.aws_iam_policy_document.concourse_worker.json
}

resource "aws_iam_instance_profile" "concourse_web" {
  name = aws_iam_role.concourse_web.name
  role = aws_iam_role.concourse_web.id
}

resource "aws_iam_instance_profile" "concourse_worker" {
  name = var.concourse_worker_conf.instance_iam_role == null ? aws_iam_role.concourse_worker[0].id : var.concourse_worker_conf.instance_iam_role
  role = var.concourse_worker_conf.instance_iam_role == null ? aws_iam_role.concourse_worker[0].id : var.concourse_worker_conf.instance_iam_role
}

resource "aws_iam_role_policy_attachment" "concourse_web_cloudwatch_logging" {
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
  role       = aws_iam_role.concourse_web.id
}

resource "aws_iam_role_policy_attachment" "concourse_worker_cloudwatch_logging" {
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
  role       = var.concourse_worker_conf.instance_iam_role == null ? aws_iam_role.concourse_worker[0].id : var.concourse_worker_conf.instance_iam_role
}

resource "aws_iam_role_policy_attachment" "concourse_web_ssm" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  role       = aws_iam_role.concourse_web.id
}

resource "aws_iam_role_policy_attachment" "concourse_worker_ssm" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  role       = var.concourse_worker_conf.instance_iam_role == null ? aws_iam_role.concourse_worker[0].id : var.concourse_worker_conf.instance_iam_role
}

resource "aws_iam_role_policy_attachment" "concourse_worker_ecr_read_access" {
  count      = var.allow_worker_access_to_ecr ? 1 : 0
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = var.concourse_worker_conf.instance_iam_role == null ? aws_iam_role.concourse_worker[0].id : var.concourse_worker_conf.instance_iam_role
}

resource "aws_iam_role_policy_attachment" "concourse_web_secrets_manager" {
  policy_arn = aws_iam_policy.concourse_web_secrets_manager.arn
  role       = aws_iam_role.concourse_web.id
}

resource "aws_iam_policy" "concourse_web_secrets_manager" {
  name        = "${local.environment}-concourse-web-secrets-manager"
  description = "Allow concourse-web Instances to access Secrets Manager"
  policy      = data.aws_iam_policy_document.concourse_web_secrets_manager.json
}

data "aws_iam_policy_document" "concourse_common_log_retention_policy" {
  statement {
    actions = [
      "logs:PutRetentionPolicy",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "concourse_web_log_retention_policy" {
  name   = "retention-policy"
  role   = aws_iam_role.concourse_web.id
  policy = data.aws_iam_policy_document.concourse_common_log_retention_policy.json
}

resource "aws_iam_role_policy" "concourse_worker_log_retention_policy" {
  name   = "retention-policy"
  role   = var.concourse_worker_conf.instance_iam_role == null ? aws_iam_role.concourse_worker[0].id : var.concourse_worker_conf.instance_iam_role
  policy = data.aws_iam_policy_document.concourse_common_log_retention_policy.json
}

data "aws_iam_policy_document" "concourse_web_secrets_manager" {
  statement {
    actions = [
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret",
    ]

    resources = [
      var.concourse_sec.session_signing_key_private_secret_arn,
      var.concourse_sec.session_signing_key_public_secret_arn,
      var.concourse_sec.tsa_host_key_private_secret_arn,
      var.concourse_sec.tsa_host_key_public_secret_arn,
      var.concourse_sec.worker_key_private_secret_arn,
      var.concourse_sec.worker_key_public_secret_arn,
      "arn:aws:secretsmanager:*:*:secret:/concourse/*",
      # What's tghis ARN below? See Concourse docs here https://concourse-ci.org/aws-asm-credential-manager.html#aws-secretsmanager-iam-permissions
      "arn:aws:secretsmanager:*:*:secret:__concourse-health-check-??????",
    ]
  }
}

resource "aws_iam_role_policy_attachment" "concourse_worker_secrets_manager" {
  policy_arn = aws_iam_policy.concourse_worker_secrets_manager.arn
  role       = var.concourse_worker_conf.instance_iam_role == null ? aws_iam_role.concourse_worker[0].id : var.concourse_worker_conf.instance_iam_role
}

resource "aws_iam_policy" "concourse_worker_secrets_manager" {
  name        = "${local.environment}-concourse-worker-secrets-manager"
  description = "Allow concourse-worker Instances to access Secrets Manager"
  policy      = data.aws_iam_policy_document.concourse_worker_secrets_manager.json
}

data "aws_iam_policy_document" "concourse_worker_secrets_manager" {
  statement {
    actions = ["secretsmanager:GetSecretValue"]

    resources = [
      var.concourse_sec.tsa_host_key_public_secret_arn,
      var.concourse_sec.worker_key_private_secret_arn,
    ]
  }
}

data "aws_iam_policy_document" "concourse_web" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "concourse_worker" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "concourse_worker_autoscaling" {
  statement {
    actions = [
      "autoscaling:SetInstanceHealth",
      "autoscaling:CompleteLifecycleAction"
    ]

    resources = [aws_autoscaling_group.worker.arn]
  }
}

resource "aws_iam_policy" "concourse_worker_autoscaling" {
  name        = "${local.environment}-concourse-worker-asg"
  description = "Change Concourse Worker's Instance Health"
  policy      = data.aws_iam_policy_document.concourse_worker_autoscaling.json
}

resource "aws_iam_role_policy_attachment" "concourse_worker_autoscaling" {
  policy_arn = aws_iam_policy.concourse_worker_autoscaling.arn
  role       = var.concourse_worker_conf.instance_iam_role == null ? aws_iam_role.concourse_worker[0].id : var.concourse_worker_conf.instance_iam_role
}

data "aws_iam_policy_document" "concourse_tag_ec2" {
  statement {
    actions = [
      "ec2:DescribeInstances",
      "ec2:CreateTags"
    ]

    resources = ["*"]
  }
}

resource "aws_iam_policy" "concourse_tag_ec2" {
  name        = "${local.name}EC2"
  description = "Change Concourse Worker's Tags"
  policy      = data.aws_iam_policy_document.concourse_tag_ec2.json
}

resource "aws_iam_role_policy_attachment" "concourse_tag_ec2" {
  policy_arn = aws_iam_policy.concourse_tag_ec2.arn
  role       = var.concourse_worker_conf.instance_iam_role == null ? aws_iam_role.concourse_worker[0].id : var.concourse_worker_conf.instance_iam_role
}

data "aws_iam_policy_document" "concourse_worker_assume_ci_role_default" {
  statement {
    sid = "AllowConcourseWorkerAssumeCIRoleDefault"
    actions = [
      "sts:AssumeRole",
    ]

    resources = ["arn:aws:iam::${local.account}:role/ci"]
  }
}

data "aws_iam_policy_document" "concourse_worker_assume_ci_role_custom" {
  statement {
    sid = "AllowConcourseWorkerAssumeCIRoleCustom"
    actions = [
      "sts:AssumeRole",
    ]

    resources = var.concourse_worker_conf.worker_assume_ci_roles
  }
}

resource "aws_iam_policy" "concourse_worker_assume_ci_role" {
  name        = "${local.environment}-concourse-worker-assume-ci-role"
  description = "Allow Concourse Workers to assume the CI Role"
  policy      = var.concourse_worker_conf.worker_assume_ci_roles == null ? data.aws_iam_policy_document.concourse_worker_assume_ci_role_default.json : data.aws_iam_policy_document.concourse_worker_assume_ci_role_custom.json
}

resource "aws_iam_role_policy_attachment" "concourse_worker_assume_ci_role" {
  policy_arn = aws_iam_policy.concourse_worker_assume_ci_role.arn
  role       = var.concourse_worker_conf.instance_iam_role == null ? aws_iam_role.concourse_worker[0].id : var.concourse_worker_conf.instance_iam_role
}
