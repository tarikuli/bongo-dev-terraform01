output "vpc_id" {
  description = "ID of the VPC."
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "IDs of both public subnets, one per AZ."
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "IDs of both private subnets, one per AZ."
  value       = aws_subnet.private[*].id
}
