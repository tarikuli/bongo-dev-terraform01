output "rds_endpoint" {
  description = "RDS connection endpoint (host:port). Not the password — see rds_secret_arn for that."
  value       = aws_db_instance.main.endpoint
}

output "rds_secret_arn" {
  description = "ARN of the Secrets Manager secret holding the master username/password. Fetch the value with: aws secretsmanager get-secret-value --secret-id <this arn>"
  value       = aws_secretsmanager_secret.rds.arn
}
