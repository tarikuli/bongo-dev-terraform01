# An `output` prints a value after `terraform apply` finishes, and lets other
# Terraform configs read it too (via `terraform_remote_state`). Here it just
# passes the ec2 module's own output through, so you don't have to look up
# the IP in the AWS console.
output "instance_public_ip" {
  description = "Public IP address of the EC2 web instance."
  value       = module.ec2.instance_public_ip
}
