
resource "aws_iam_policy" "manage_web_ip_address_access" {
  name        = "web-ip-address-access"
  path        = "/"
  description = "Permission to invoke the lambda: concourse-web-manage-ip-address-access"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "lambda:InvokeFunctionUrl",
        ]
        Effect   = "Allow"
        Resource = aws_lambda_function.manage_web_ip_address_access_add.arn
      },
    ]
  })
}

// ----------------------------

resource "aws_iam_role" "manage_web_ip_address_access" {
  name               = "concourse-web-manage-ip-address-access"
  assume_role_policy = data.aws_iam_policy_document.lambda.json
}

resource "aws_iam_role_policy_attachment" "manage_web_ip_address_access_basic" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  role       = aws_iam_role.manage_web_ip_address_access.name
}

data "aws_iam_policy_document" "manage_web_ip_address_access" {
  statement {
    effect = "Allow"
    actions = [
      "ec2:AuthorizeSecurityGroupIngress",
      "ec2:RevokeSecurityGroupIngress",
    ]
    resources = [
      "arn:aws:ec2:${data.aws_region.current.name}:${local.account}:security-group/${aws_security_group.concourse_lb_clients.id}"
    ]
  }
  statement {
    effect = "Allow"
    actions = [
      "ec2:DescribeSecurityGroupRules",
    ]
    resources = [
      "*"
    ]
  }
}

resource "aws_iam_role_policy" "manage_web_ip_address_access_inline" {
  role   = aws_iam_role.manage_web_ip_address_access.name
  name   = "ec2"
  policy = data.aws_iam_policy_document.manage_web_ip_address_access.json
}

# ---------------------------------------------------------
# Adding new IP Addresses

data "archive_file" "manage_web_ip_address_access_add" {
  type        = "zip"
  source_file = "${path.module}/files/client_ip_management_lambda/add.py"
  output_path = "${path.module}/files/client_ip_management_lambda/add.zip"
}

resource "aws_lambda_function" "manage_web_ip_address_access_add" {
  function_name = "concourse-web-manage-ip-address-access-add"

  filename         = data.archive_file.manage_web_ip_address_access_add.output_path
  source_code_hash = data.archive_file.manage_web_ip_address_access_add.output_base64sha256

  role        = aws_iam_role.manage_web_ip_address_access.arn
  handler     = "add.handler"
  runtime     = "python3.9"
  timeout     = 30
  memory_size = 512

  environment {
    variables = {
      SECURITY_GROUP = aws_security_group.concourse_lb_clients.id
    }
  }
}

resource "aws_lambda_function_url" "manage_web_ip_address_access_add" {
  function_name      = aws_lambda_function.manage_web_ip_address_access_add.function_name
  authorization_type = "AWS_IAM"
}

# ---------------------------------------------------------
# Flushing all IP addresses

data "archive_file" "manage_web_ip_address_access_flush" {
  type        = "zip"
  source_file = "${path.module}/files/client_ip_management_lambda/flush.py"
  output_path = "${path.module}/files/client_ip_management_lambda/flush.zip"
}

resource "aws_lambda_function" "manage_web_ip_address_access_flush" {
  function_name = "concourse-web-manage-ip-address-access-flush"

  filename         = data.archive_file.manage_web_ip_address_access_flush.output_path
  source_code_hash = data.archive_file.manage_web_ip_address_access_flush.output_base64sha256

  role        = aws_iam_role.manage_web_ip_address_access.arn
  handler     = "flush.handler"
  runtime     = "python3.9"
  timeout     = 900
  memory_size = 512

  environment {
    variables = {
      SECURITY_GROUP = aws_security_group.concourse_lb_clients.id
    }
  }
}

resource "aws_lambda_permission" "manage_web_ip_address_access_flush" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.manage_web_ip_address_access_flush.function_name
  principal     = "events.amazonaws.com"
}

resource "aws_cloudwatch_event_rule" "manage_web_ip_address_access_flush" {
  name                = "concourse-web-manage-ip-address-access-flush"
  description         = "Flush IP addresses"
  schedule_expression = "cron(0 0 * * ? *)"
}

resource "aws_cloudwatch_event_target" "manage_web_ip_address_access_flush" {
  rule      = aws_cloudwatch_event_rule.manage_web_ip_address_access_flush.name
  target_id = "processing_lambda"
  arn       = aws_lambda_function.manage_web_ip_address_access_flush.arn
}
