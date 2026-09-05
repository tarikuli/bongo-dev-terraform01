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
