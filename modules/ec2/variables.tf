variable "vpc_id" {
  description = "VPC to create the instance security group in."
  type        = string
}

variable "subnet_ids" {
  description = "Public subnets (2, across 2 AZs) the ASG launches instances into."
  type        = list(string)
}

variable "instance_type" {
  description = "EC2 instance type."
  type        = string
}

variable "root_volume_size" {
  description = "Root volume size in GB."
  type        = number
}

variable "my_ip_cidr" {
  description = "CIDR allowed to SSH into instances, e.g. 203.0.113.5/32."
  type        = string
}

variable "key_name" {
  description = "Name of an existing EC2 key pair for SSH access. Leave null to launch without one."
  type        = string
  default     = null
}

variable "alb_security_group_id" {
  description = "Security group of the ALB — instances allow inbound HTTP only from this."
  type        = string
}

variable "target_group_arn" {
  description = "ALB target group ARN the Auto Scaling Group registers instances with."
  type        = string
}

variable "asg_min_size" {
  description = "Minimum number of instances in the Auto Scaling Group."
  type        = number
  default     = 1
}

variable "asg_max_size" {
  description = "Maximum number of instances in the Auto Scaling Group."
  type        = number
  default     = 2
}

variable "asg_desired_capacity" {
  description = "Desired number of instances in the Auto Scaling Group."
  type        = number
  default     = 1
}
