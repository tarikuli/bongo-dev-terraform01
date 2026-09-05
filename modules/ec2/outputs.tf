output "asg_name" {
  description = "Name of the Auto Scaling Group."
  value       = aws_autoscaling_group.web.name
}

output "security_group_id" {
  description = "ID of the security group attached to instances."
  value       = aws_security_group.web.id
}

output "launch_template_id" {
  description = "ID of the launch template instances are created from."
  value       = aws_launch_template.web.id
}
