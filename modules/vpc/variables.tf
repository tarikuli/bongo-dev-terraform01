variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for the public subnets — one per availability zone, same order as availability_zones."
  type        = list(string)

  validation {
    condition     = length(var.public_subnet_cidrs) == 2
    error_message = "public_subnet_cidrs must have exactly 2 entries — the ALB and ASG need 2 public subnets in 2 AZs."
  }
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for the private subnets — one per availability zone, same order as availability_zones."
  type        = list(string)

  validation {
    condition     = length(var.private_subnet_cidrs) == 2
    error_message = "private_subnet_cidrs must have exactly 2 entries — RDS's DB subnet group needs 2 private subnets in 2 AZs."
  }
}

variable "availability_zones" {
  description = "Two availability zones — the public and private subnets each place one in each AZ."
  type        = list(string)

  validation {
    condition     = length(var.availability_zones) == 2
    error_message = "availability_zones must have exactly 2 entries, matching public_subnet_cidrs and private_subnet_cidrs."
  }
}
