resource "aws_autoscaling_group" "concourse_web" {
  name_prefix           = "concourse-web-"
  max_size              = var.concourse_web_conf.count
  min_size              = var.concourse_web_conf.count
  desired_capacity      = var.concourse_web_conf.count
  max_instance_lifetime = var.concourse_web_conf.max_instance_lifetime

  # Only add the webhook SG if the auth ALB feature is enabled
  target_group_arns = var.concourse_auth_alb_conf.enable_auth_alb == false ? [
    aws_lb_target_group.concourse_web_http.arn,
    aws_lb_target_group.web_ssh.arn,
    ] : [
    aws_lb_target_group.concourse_web_http.arn,
    aws_lb_target_group.web_ssh.arn,
    aws_lb_target_group.concourse_hooks_http[0].arn,
  ]

  #   target_group_arns = [
  #     aws_lb_target_group.concourse_web_http.arn,
  #     aws_lb_target_group.web_ssh.arn,
  #     # Only include the web hooks target group if the authenticating load balancer feature is enabled
  #     # condition ? true_val : false_val
  #     var.concourse_auth_alb_conf.enable_auth_alb == false ? null : aws_lb_target_group.concourse_hooks_http[0].arn,
  #   ]

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
    id      = aws_launch_template.concourse_web.id
    version = aws_launch_template.concourse_web.latest_version
  }

  lifecycle {
    create_before_destroy = true
    ignore_changes        = [max_size]
  }

  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = var.concourse_web_conf.min_healthy_percentage
    }
  }
}

resource "aws_autoscaling_schedule" "concourse_web_night" {
  scheduled_action_name  = "night"
  autoscaling_group_name = aws_autoscaling_group.concourse_web.name
  recurrence             = var.concourse_web_conf.asg_scaling_config.night.time

  min_size         = var.concourse_web_conf.asg_scaling_config.night.min_size
  max_size         = var.concourse_web_conf.asg_scaling_config.night.max_size
  desired_capacity = var.concourse_web_conf.asg_scaling_config.night.desired_capacity

  time_zone = "Europe/London"
}

resource "aws_autoscaling_schedule" "concourse_web_day" {
  scheduled_action_name  = "day"
  autoscaling_group_name = aws_autoscaling_group.concourse_web.name
  recurrence             = var.concourse_web_conf.asg_scaling_config.day.time

  min_size         = var.concourse_web_conf.asg_scaling_config.day.min_size
  max_size         = var.concourse_web_conf.asg_scaling_config.day.max_size
  desired_capacity = var.concourse_web_conf.asg_scaling_config.day.desired_capacity

  time_zone = "Europe/London"
}

resource "aws_autoscaling_policy" "concourse_web_scale_up" {
  name                   = "concourse-web-scale-up"
  scaling_adjustment     = 1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 180
  autoscaling_group_name = aws_autoscaling_group.concourse_web.name
}

resource "aws_autoscaling_policy" "concourse_web_scale_down" {
  name                   = "concourse-web-scale-down"
  scaling_adjustment     = -1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 180
  autoscaling_group_name = aws_autoscaling_group.concourse_web.name
}

resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  alarm_name          = "concourse-cpu-util-high-web"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "3"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "60"
  statistic           = "Average"
  threshold           = "90"
  alarm_description   = "This metric monitors ec2 cpu for high utilization on web nodes"
  alarm_actions       = [aws_autoscaling_policy.concourse_web_scale_up.arn]
  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.concourse_web.name
  }
}

resource "aws_cloudwatch_metric_alarm" "cpu-low" {
  alarm_name          = "concourse-cpu-util-low-web"
  comparison_operator = "LessThanOrEqualToThreshold"
  evaluation_periods  = "3"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "60"
  statistic           = "Average"
  threshold           = "10"
  alarm_description   = "This metric monitors ec2 cpu for low utilization on agent hosts"
  alarm_actions       = [aws_autoscaling_policy.concourse_web_scale_down.arn]
  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.concourse_web.name
  }
}
