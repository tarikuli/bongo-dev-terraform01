variable "vpc_id" {
  description = "VPC to create the security group in."
  type        = string
}

variable "subnet_id" {
  description = "Subnet to launch the instance into (must be public for HTTP/SSH access to work)."
  type        = string
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
  description = "CIDR allowed to SSH into the instance, e.g. 203.0.113.5/32."
  type        = string
}

variable "key_name" {
  description = "Name of an existing EC2 key pair for SSH access. Leave null to launch without one."
  type        = string
  default     = null
}
