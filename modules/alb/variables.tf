variable "vpc_id" {
  description = "VPC to create the ALB's security group and target group in."
  type        = string
}

variable "public_subnet_ids" {
  description = "Public subnets (2, across 2 AZs) for the ALB to attach to."
  type        = list(string)
}

variable "health_check_path" {
  description = "Path the target group requests to check instance health."
  type        = string
  default     = "/"
}
