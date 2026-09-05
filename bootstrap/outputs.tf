output "state_bucket_name" {
  description = "S3 bucket name to use as `bucket` in the root project's backend.tf."
  value       = aws_s3_bucket.terraform_state.bucket
}

output "dynamodb_table_name" {
  description = "DynamoDB table name to use as `dynamodb_table` in the root project's backend.tf."
  value       = aws_dynamodb_table.terraform_locks.name
}
