variable "vpc_id" {
  description = "VPC to create the RDS security group in."
  type        = string
}

variable "private_subnet_ids" {
  description = "Two private subnets (across 2 AZs) for the DB subnet group."
  type        = list(string)

  validation {
    condition     = length(var.private_subnet_ids) == 2
    error_message = "private_subnet_ids must have exactly 2 entries — a DB subnet group needs subnets in 2 AZs."
  }
}

variable "ec2_security_group_id" {
  description = "Security group of the EC2/ASG instances — the only thing allowed to reach MySQL."
  type        = string
}

variable "instance_class" {
  description = "RDS instance class."
  type        = string
  default     = "db.t4g.micro"
}

variable "allocated_storage" {
  description = "Allocated storage in GB."
  type        = number
  default     = 20
}

variable "engine_version" {
  description = "MySQL engine version."
  type        = string
  default     = "8.0"
}

variable "db_name" {
  description = "Name of the initial database created on the instance."
  type        = string
  default     = "appdb"
}

variable "db_username" {
  description = "Master username. Not the password — that's generated randomly and stored in Secrets Manager."
  type        = string
  default     = "dbadmin"
}

variable "backup_retention_period" {
  description = "Days to retain automated backups. 0 disables them — fine for a learning project, raise it for anything real."
  type        = number
  default     = 0
}
