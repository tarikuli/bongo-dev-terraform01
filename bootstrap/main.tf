# Used to build a bucket name that's globally unique without you having to
# pick one by hand — S3 bucket names must be unique across ALL of AWS, not
# just your account.
data "aws_caller_identity" "current" {}

# --- State storage ---

resource "aws_s3_bucket" "terraform_state" {
  bucket = "${var.project_name}-tfstate-${data.aws_caller_identity.current.account_id}"

  tags = {
    Name    = "${var.project_name}-tfstate"
    Purpose = "Terraform remote state"
  }
}

# Versioning keeps every previous version of the state file. If a bad apply
# corrupts or wipes your state, you can roll back to an earlier version
# instead of losing track of your infrastructure entirely.
resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Default (server-side) encryption: every object written to this bucket is
# encrypted at rest automatically, even if whoever runs `apply` forgets to
# ask for it. State files can contain sensitive values, so this matters.
resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Belt-and-suspenders: blocks this bucket from ever being made public, no
# matter what ACLs or bucket policies get added later by mistake.
resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# --- State locking ---

# Terraform uses this table to take a "lock" while running plan/apply, so
# two people (or two CI runs) can't modify the same state file at the same
# time and corrupt it. The table just needs a single primary key named
# exactly "LockID" — Terraform manages the rest.
resource "aws_dynamodb_table" "terraform_locks" {
  name         = "${var.project_name}-terraform-locks"
  billing_mode = "PAY_PER_REQUEST" # on-demand pricing — no capacity to size for this tiny workload
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S" # string
  }

  tags = {
    Name    = "${var.project_name}-terraform-locks"
    Purpose = "Terraform state locking"
  }
}
