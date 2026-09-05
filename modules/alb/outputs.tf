output "alb_dns_name" {
  description = "Public DNS name of the ALB."
  value       = aws_lb.web.dns_name
}

output "alb_security_group_id" {
  description = "ID of the ALB's security group — EC2 instances allow HTTP only from this."
  value       = aws_security_group.alb.id
}

output "target_group_arn" {
  description = "ARN of the target group the ASG should register instances with."
  value       = aws_lb_target_group.web.arn
}

# CloudWatch's AWS/ApplicationELB metrics (e.g. UnHealthyHostCount) key their
# LoadBalancer/TargetGroup dimensions on this shortened "arn_suffix" form
# rather than the full ARN — a separate computed attribute the provider
# exposes specifically for this.
output "alb_arn_suffix" {
  description = "Short form of the ALB's ARN, used as a CloudWatch metric dimension."
  value       = aws_lb.web.arn_suffix
}

output "target_group_arn_suffix" {
  description = "Short form of the target group's ARN, used as a CloudWatch metric dimension."
  value       = aws_lb_target_group.web.arn_suffix
}
