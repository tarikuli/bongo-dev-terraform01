# This file declares every input the configuration accepts. A `variable` block
# is like a function parameter: `main.tf` reads it back with `var.<name>`.
# Variables with a `default` are optional to set; variables without one (like
# `my_ip_cidr` below) are required — Terraform will prompt for them if missing.

variable "aws_region" {
  description = "AWS region to deploy into."
  type        = string
  default     = "us-east-1"
}

variable "availability_zones" {
  description = "Two AZs (within aws_region) for the public subnets, ALB, and ASG to span."
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

# --- CIDR blocks ---
# A CIDR block (e.g. 10.0.0.0/16) defines a range of IP addresses. The
# VPC gets one big range, and each subnet gets a smaller slice of it.
# "/16" = 65,536 addresses, "/24" = 256 addresses.

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for the two public subnets (one per AZ in availability_zones)."
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.3.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for the two private subnets (one per AZ in availability_zones) — used by RDS's DB subnet group."
  type        = list(string)
  default     = ["10.0.2.0/24", "10.0.4.0/24"]
}

variable "instance_type" {
  description = "EC2 instance type used by the launch template."
  type        = string
  default     = "t3.micro"
}

variable "root_volume_size" {
  description = "Root volume size in GB."
  type        = number
  default     = 8
}

# --- Auto Scaling Group sizing ---
# Kept small on purpose to control cost — bump these up if you actually need
# more capacity or higher availability.

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

variable "health_check_path" {
  description = "Path the ALB target group requests to check instance health."
  type        = string
  default     = "/"
}

# No default on purpose: forces you to explicitly pass your own IP
# (e.g. -var="my_ip_cidr=203.0.113.5/32") instead of silently defaulting
# to something that could open SSH to the entire internet.
variable "my_ip_cidr" {
  description = "Your public IP in CIDR notation (e.g. 203.0.113.5/32), allowed to SSH into the instance. Required — no default, so nobody accidentally opens SSH to the world."
  type        = string

  # `validation` blocks let Terraform reject bad input at plan time, with a
  # clear error message, instead of failing later inside AWS.
  validation {
    condition     = can(cidrhost(var.my_ip_cidr, 0))
    error_message = "my_ip_cidr must be a valid CIDR block, e.g. 203.0.113.5/32."
  }
}

variable "key_name" {
  description = "Name of an existing EC2 key pair to associate with the instance for SSH access. Leave null to launch without a key pair."
  type        = string
  default     = null
}

# --- RDS ---
# The master password is deliberately NOT a variable here — it's generated
# randomly by modules/rds and stored in Secrets Manager instead. See
# modules/rds/main.tf's random_password resource.

variable "db_instance_class" {
  description = "RDS instance class."
  type        = string
  default     = "db.t4g.micro"
}

variable "db_allocated_storage" {
  description = "RDS allocated storage in GB."
  type        = number
  default     = 20
}

variable "db_engine_version" {
  description = "MySQL engine version."
  type        = string
  default     = "8.0"
}

variable "db_name" {
  description = "Name of the initial database created on the RDS instance."
  type        = string
  default     = "appdb"
}

variable "db_username" {
  description = "RDS master username (not the password — see above)."
  type        = string
  default     = "dbadmin"
}

variable "db_backup_retention_days" {
  description = "Days to retain automated RDS backups. 0 disables them — fine for a learning project, raise it for anything real."
  type        = number
  default     = 0
}
