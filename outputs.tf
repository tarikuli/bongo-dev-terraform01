# An `output` prints a value after `terraform apply` finishes, and lets other
# Terraform configs read it too (via `terraform_remote_state`). Here it just
# passes the alb module's own output through, so you don't have to look up
# the DNS name in the AWS console. There's no single instance IP to output
# anymore — traffic goes through the ALB, which spreads it across however
# many instances the ASG is currently running.
output "alb_dns_name" {
  description = "Public DNS name of the ALB — open this in a browser to reach the app."
  value       = module.alb.alb_dns_name
}

output "rds_endpoint" {
  description = "RDS connection endpoint (host:port). The master password is deliberately not output here — see rds_secret_arn."
  value       = module.rds.rds_endpoint
}

output "rds_secret_arn" {
  description = "ARN of the Secrets Manager secret holding the RDS master username/password. Retrieve it with: aws secretsmanager get-secret-value --secret-id <this arn> --query SecretString --output text"
  value       = module.rds.rds_secret_arn
}
