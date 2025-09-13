
resource "aws_autoscaling_group" "worker" {
  depends_on  = [aws_autoscaling_group.concourse_web]
  name_prefix = "concourse-worker-"

  // The min and max size set here are only applied until the first scheduled `aws_autoscaling_schedule`.
  // We therefore just play it safe and select the overall min and max values seen in the config.
  min_size = min(
    var.concourse_worker_conf.count,
    var.concourse_worker_conf.asg_scaling_config.day.min_size
  )
  max_size = max(
    var.concourse_worker_conf.count,
    var.concourse_worker_conf.asg_scaling_config.day.max_size
  )

  desired_capacity = var.concourse_worker_conf.count

  vpc_zone_identifier = local.vpc.private_subnets

  // Oldest instance isn't guaranteed by default.
  termination_policies = ["OldestInstance", "Default"]

  dynamic "tag" {
    for_each = var.tags

    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }

  launch_template {
    id      = aws_launch_template.concourse_worker.id
    version = aws_launch_template.concourse_worker.latest_version
  }

  lifecycle {
    create_before_destroy = true
  }

  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = var.concourse_worker_conf.min_healthy_percentage
    }
  }

  enabled_metrics = [
    "GroupDesiredCapacity",
    "GroupInServiceCapacity",
    "GroupInServiceInstances",
    "GroupMaxSize",
    "GroupMinSize",
    "GroupPendingCapacity",
    "GroupPendingInstances",
    "GroupStandbyCapacity",
    "GroupStandbyInstances",
    "GroupTerminatingCapacity",
    "GroupTerminatingInstances",
    "GroupTotalCapacity",
    "GroupTotalInstances",
  ]

}

//-----------------------------------------------------------------------------------
// Scheduled scaling policy
//  These should be used to manage the min and max values; but not desired values.

resource "aws_autoscaling_schedule" "concourse_worker_night" {
  scheduled_action_name  = "night"
  autoscaling_group_name = aws_autoscaling_group.worker.name
  recurrence             = var.concourse_worker_conf.asg_scaling_config.night.time

  desired_capacity = -1 // Means 'do not change.' i.e. allow tracked autoscaling to manage this.
  min_size         = var.concourse_worker_conf.asg_scaling_config.night.min_size
  max_size         = var.concourse_worker_conf.asg_scaling_config.night.max_size

  time_zone = "Europe/London"
}

resource "aws_autoscaling_schedule" "concourse_worker_day" {
  scheduled_action_name  = "day"
  autoscaling_group_name = aws_autoscaling_group.worker.name
  recurrence             = var.concourse_worker_conf.asg_scaling_config.day.time

  desired_capacity = -1 // Means 'do not change.' i.e. allow tracked autoscaling to manage this.
  min_size         = var.concourse_worker_conf.asg_scaling_config.day.min_size
  max_size         = var.concourse_worker_conf.asg_scaling_config.day.max_size

  time_zone = "Europe/London"
}

//-----------------------------------------------------------------------------------
// Load based scaling policy
//  Controls desired values.

resource "aws_autoscaling_policy" "concourse_worker_tracked" {
  name                   = "concourse-worker-tracked-scaling"
  autoscaling_group_name = aws_autoscaling_group.worker.name
  policy_type            = "TargetTrackingScaling"

  estimated_instance_warmup = 300

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }

    target_value = var.concourse_worker_cpu_tracked_scaling_target
  }
}

//-----------------------------------------------------------------------------------
// Scale-in hook
//  Notifies SNS that autoscaling wishes to terminate an instance.

resource "aws_sns_topic" "worker_scale_down" {
  name = "concourse-worker-scale-down"
}


resource "aws_autoscaling_lifecycle_hook" "worker_scale_in" {
  name                   = "scale-in"
  autoscaling_group_name = aws_autoscaling_group.worker.name
  default_result         = "CONTINUE"
  heartbeat_timeout      = 60 * 60 * 2 // Set to 2 hours (max value) as a fail safe for if the retire fails.
  lifecycle_transition   = "autoscaling:EC2_INSTANCE_TERMINATING"

  notification_target_arn = aws_sns_topic.worker_scale_down.arn
  role_arn                = aws_iam_role.concourse_worker_autoscaling_notification.arn
}

resource "aws_iam_role" "concourse_worker_autoscaling_notification" {
  name               = "${local.environment}-concourse-worker-autoscaling-notification"
  assume_role_policy = data.aws_iam_policy_document.autoscaling.json

  tags = merge(
    local.common_tags,
    { Name = "${local.environment}-concourse-worker-autoscaling-notification" }
  )
}

data "aws_iam_policy_document" "autoscaling" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["autoscaling.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy_attachment" "concourse_worker_autoscaling_notification" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AutoScalingNotificationAccessRole"
  role       = aws_iam_role.concourse_worker_autoscaling_notification.id
}

//-----------------------------------------------------------------------------------
// Retire instance SSM Command Document
//  Can be called from SSM to put Concourse on an instance into a 'retiring' mode.

locals {
  worker_shutdown_command = templatefile(
    "${path.module}/files/concourse_worker/retire_worker.yaml",
    {
      lifecycle_hook_name     = aws_autoscaling_lifecycle_hook.worker_scale_in.name
      auto_scaling_group_name = aws_autoscaling_group.worker.name
    }
  )
}

resource "aws_ssm_document" "worker_shutdown_command" {
  name            = "concourse-worker-shutdown"
  document_format = "YAML"
  document_type   = "Command"
  content         = local.worker_shutdown_command
}

//-----------------------------------------------------------------------------------
// Lambda triggered by the scale-in SNS notification,
//  that calls the 'retire' command, via SSM.

resource "aws_iam_role" "concourse_worker_autoscaling_lambda" {
  name               = "${local.environment}-concourse-worker-autoscaling-lambda"
  assume_role_policy = data.aws_iam_policy_document.lambda.json
}

data "aws_iam_policy_document" "lambda" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy_attachment" "concourse_worker_autoscaling_lambda" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  role       = aws_iam_role.concourse_worker_autoscaling_lambda.name
}

data "aws_iam_policy_document" "concourse_worker_autoscaling_lambda" {
  statement {
    effect = "Allow"
    actions = [
      "ssm:SendCommand"
    ]
    resources = [
      aws_ssm_document.worker_shutdown_command.arn,
      "arn:aws:ec2:${data.aws_region.current.name}:${local.account}:instance/*"
    ]
  }
}

resource "aws_iam_role_policy" "concourse_worker_autoscaling_lambda" {
  role   = aws_iam_role.concourse_worker_autoscaling_lambda.name
  name   = "ssm"
  policy = data.aws_iam_policy_document.concourse_worker_autoscaling_lambda.json
}

data "archive_file" "concourse_worker_autoscaling_notification" {
  type        = "zip"
  source_file = "${path.module}/files/asg_hook_lambda/handler.py"
  output_path = "${path.module}/files/asg_hook_lambda/handler.zip"
}

resource "aws_lambda_function" "concourse_worker_autoscaling_notification" {
  function_name = "concourse-worker-autoscaling-notification"

  filename         = data.archive_file.concourse_worker_autoscaling_notification.output_path
  source_code_hash = data.archive_file.concourse_worker_autoscaling_notification.output_base64sha256

  role        = aws_iam_role.concourse_worker_autoscaling_lambda.arn
  handler     = "handler.handler"
  runtime     = "python3.9"
  timeout     = 10
  memory_size = 512

  tags = var.tags

  environment {
    variables = {
      DOCUMENT_NAME = aws_ssm_document.worker_shutdown_command.name
    }
  }
}

resource "aws_sns_topic_subscription" "concourse_worker_autoscaling_notification" {
  topic_arn = aws_sns_topic.worker_scale_down.arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.concourse_worker_autoscaling_notification.arn
}

resource "aws_lambda_permission" "concourse_worker_autoscaling_notification" {
  statement_id  = "AllowExecutionFromSNSfinalsel"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.concourse_worker_autoscaling_notification.arn
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.worker_scale_down.arn
}
