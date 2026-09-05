# An `output` prints a value after `terraform apply` finishes, and lets other
# Terraform configs read it too (via `terraform_remote_state`). Here it just
# surfaces the instance's public IP so you don't have to look it up in the
# AWS console.
output "instance_public_ip" {
  description = "Public IP address of the EC2 web instance."
  value       = aws_instance.web.public_ip
}
