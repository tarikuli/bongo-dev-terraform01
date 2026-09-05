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
