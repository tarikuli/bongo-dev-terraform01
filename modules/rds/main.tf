# A DB subnet group tells RDS which subnets it's allowed to place the
# database (and its Multi-AZ standby, if enabled) into. RDS requires at
# least 2 AZs here even when multi_az is false on the instance itself.
resource "aws_db_subnet_group" "main" {
  name       = "bongo-dev-db-subnet-group"
  subnet_ids = var.private_subnet_ids

  tags = {
    Name = "bongo-dev-db-subnet-group"
  }
}

# The database's firewall: only the EC2/ASG security group — not a CIDR
# block — is allowed to reach MySQL. Nothing outside that security group,
# including the internet, can connect even though these are private
# subnets.
resource "aws_security_group" "rds" {
  name        = "bongo-dev-rds-sg"
  description = "Allow MySQL only from the EC2/ASG security group"
  vpc_id      = var.vpc_id

  ingress {
    description     = "MySQL from the app servers only"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [var.ec2_security_group_id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "bongo-dev-rds-sg"
  }
}

# Generates a random master password instead of asking for one in a
# variable (which would otherwise end up in plaintext in .tfvars files,
# shell history, or CI logs). `random_password`'s `result` attribute is
# treated as sensitive by Terraform automatically, so it's hidden from
# plan/apply output — though it's still stored in plaintext in
# terraform.tfstate, which is exactly why state should live in an
# encrypted backend (see the bootstrap/ remote state setup).
resource "random_password" "master" {
  length  = 20
  special = true
  # Excludes '/', '"', '@', and space — characters RDS rejects in a MySQL
  # master password.
  override_special = "!#$%^&*()-_=+[]{}<>:?"
  min_upper        = 1
  min_lower        = 1
  min_numeric      = 1
  min_special      = 1
}

# The actual secret "container" in Secrets Manager.
resource "aws_secretsmanager_secret" "rds" {
  name        = "bongo-dev-rds-master-credentials"
  description = "Master credentials for the bongo-dev RDS MySQL instance"

  # Secrets Manager normally keeps a deleted secret in a 7-30 day recovery
  # window before actually freeing its name. That gets in the way for a
  # learning project you expect to `destroy` and `apply` repeatedly — a
  # second apply within that window fails because the name is still
  # reserved. Setting this to 0 deletes it immediately on destroy instead.
  # (Don't do this for a secret you might need to recover.)
  recovery_window_in_days = 0

  tags = {
    Name = "bongo-dev-rds-master-credentials"
  }
}

# The actual secret value: username + the generated password, as JSON —
# the conventional shape the AWS SDKs' RDS-integration helpers expect.
resource "aws_secretsmanager_secret_version" "rds" {
  secret_id = aws_secretsmanager_secret.rds.id
  secret_string = jsonencode({
    username = var.db_username
    password = random_password.master.result
  })
}

resource "aws_db_instance" "main" {
  identifier = "bongo-dev-mysql"

  engine         = "mysql"
  engine_version = var.engine_version
  instance_class = var.instance_class

  allocated_storage = var.allocated_storage
  storage_type      = "gp3"
  storage_encrypted = true

  db_name  = var.db_name
  username = var.db_username
  password = random_password.master.result # never a plaintext variable — see random_password above

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = false # private subnets only; nothing outside the VPC can reach it

  multi_az = false # keeps cost down, per requirements — no automatic standby in a second AZ

  backup_retention_period = var.backup_retention_period
  apply_immediately       = true # apply changes right away instead of waiting for a maintenance window — fine for a learning project, riskier for production

  # Both of these trade safety for convenience, deliberately, for a
  # throwaway learning project: deletion_protection would otherwise block
  # `terraform destroy` outright, and without skip_final_snapshot, destroying
  # the instance would also try to create a final snapshot (extra time, and
  # a lingering snapshot you'd have to clean up and pay for separately).
  deletion_protection = false
  skip_final_snapshot = true

  tags = {
    Name = "bongo-dev-mysql"
  }
}
