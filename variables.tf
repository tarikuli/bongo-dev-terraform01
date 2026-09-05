# This file declares every input the configuration accepts. A `variable` block
# is like a function parameter: `main.tf` reads it back with `var.<name>`.
# Variables with a `default` are optional to set; variables without one (like
# `my_ip_cidr` below) are required — Terraform will prompt for them if missing.

variable "aws_region" {
  description = "AWS region to deploy into."
  type        = string
  default     = "us-east-1"
}

variable "availability_zone" {
  description = "Availability zone (within aws_region) for the subnets and instance."
  type        = string
  default     = "us-east-1a"
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

variable "public_subnet_cidr" {
  description = "CIDR block for the public subnet."
  type        = string
  default     = "10.0.1.0/24"
}

variable "private_subnet_cidr" {
  description = "CIDR block for the private subnet."
  type        = string
  default     = "10.0.2.0/24"
}

variable "instance_type" {
  description = "EC2 instance type."
  type        = string
  default     = "t3.micro"
}

variable "root_volume_size" {
  description = "Root volume size in GB."
  type        = number
  default     = 8
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
