# An SNS topic is just a named channel: things publish to it (here, the
# two CloudWatch alarms below), and subscribers (here, your email) receive
# whatever gets published.
resource "aws_sns_topic" "alerts" {
  name = "bongo-dev-alerts"

  tags = {
    Name = "bongo-dev-alerts"
  }
}

# Email subscriptions start in "pending confirmation" — AWS sends a
# confirmation link to this address, and no notifications are delivered
# until someone clicks it. Terraform can create the subscription but can't
# confirm it for you; check your inbox after the first apply.
resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

# Fires when the ASG's fleet-wide average CPU exceeds the threshold for one
# full 5-minute period. "AWS/EC2" + "CPUUtilization" with an
# AutoScalingGroupName dimension is a metric AWS publishes automatically —
# aggregated across every instance currently in the ASG — no extra
# instrumentation needed.
resource "aws_cloudwatch_metric_alarm" "asg_cpu_high" {
  alarm_name          = "bongo-dev-asg-cpu-high"
  alarm_description   = "ASG average CPU above ${var.cpu_alarm_threshold}% for 5 minutes"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 300 # 5 minutes, in seconds — one evaluation period covers the full window
  statistic           = "Average"
  threshold           = var.cpu_alarm_threshold

  dimensions = {
    AutoScalingGroupName = var.asg_name
  }

  # Without this, a gap in data (e.g. between an old instance terminating
  # and a new one's metrics starting) would leave the alarm stuck in
  # INSUFFICIENT_DATA rather than just treating "no data" as "not breaching".
  treat_missing_data = "notBreaching"

  alarm_actions = [aws_sns_topic.alerts.arn]
  ok_actions    = [aws_sns_topic.alerts.arn] # also notify when it recovers, not just when it fires

  tags = {
    Name = "bongo-dev-asg-cpu-high"
  }
}

# Fires the moment the ALB's target group reports even one unhealthy
# instance. "AWS/ApplicationELB" + "UnHealthyHostCount" needs BOTH the
# LoadBalancer and TargetGroup dimensions to identify which target group
# on which ALB it's counting.
resource "aws_cloudwatch_metric_alarm" "alb_unhealthy_hosts" {
  alarm_name          = "bongo-dev-alb-unhealthy-hosts"
  alarm_description   = "At least one target behind the ALB is unhealthy"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "UnHealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = 60 # ALB target health metrics report every 1 minute
  statistic           = "Average"
  threshold           = var.unhealthy_host_alarm_threshold

  dimensions = {
    LoadBalancer = var.alb_arn_suffix
    TargetGroup  = var.target_group_arn_suffix
  }

  treat_missing_data = "notBreaching"

  alarm_actions = [aws_sns_topic.alerts.arn]
  ok_actions    = [aws_sns_topic.alerts.arn]

  tags = {
    Name = "bongo-dev-alb-unhealthy-hosts"
  }
}
