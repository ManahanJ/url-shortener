output "vpc_id" {
  description = "ID of the VPC"
  value       = data.aws_vpc.default.id
}

output "private_subnet_ids" {
  description = "List of IDs of private subnets"
  value       = data.aws_subnets.default.ids
}

output "public_subnet_ids" {
  description = "List of IDs of public subnets"
  value       = data.aws_subnets.default.ids
}

output "app_security_group_id" {
  description = "ID of the application security group"
  value       = data.aws_security_group.default.id
}