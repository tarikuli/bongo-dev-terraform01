# No default on purpose: defaulting to some placeholder address would risk
# silently emailing someone unintended, the same reasoning as my_ip_cidr
# having no default in the root project.
variable "alert_email" {
  description = "Email address CloudWatch alarms notify via SNS. AWS emails a confirmation link here after apply — alarms won't actually deliver until you click it."
  type        = string

  validation {
    condition     = can(regex("^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$", var.alert_email))
    error_message = "alert_email must look like a valid email address, e.g. you@example.com."
  }
}

variable "asg_name" {
  description = "Name of the Auto Scaling Group to alarm on."
  type        = string
}

variable "alb_arn_suffix" {
  description = "Short-form ARN of the ALB (CloudWatch metric dimension)."
  type        = string
}

variable "target_group_arn_suffix" {
  description = "Short-form ARN of the target group (CloudWatch metric dimension)."
  type        = string
}

variable "cpu_alarm_threshold" {
  description = "ASG average CPU utilization (%) that triggers the alarm."
  type        = number
  default     = 70
}

variable "unhealthy_host_alarm_threshold" {
  description = "Unhealthy host count that triggers the alarm."
  type        = number
  default     = 0
}
