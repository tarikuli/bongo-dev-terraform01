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

variable "private_subnet_cidr" {
  description = "CIDR block for the (single) private subnet."
  type        = string
}

variable "availability_zones" {
  description = "Two availability zones — the public subnets each land in one; the private subnet uses the first."
  type        = list(string)

  validation {
    condition     = length(var.availability_zones) == 2
    error_message = "availability_zones must have exactly 2 entries, matching public_subnet_cidrs."
  }
}
