output "subnet_ids" {
    description = "IDs of subnet of default VPC"
    value       = data.aws_subnets.default.ids
}

output "security_group_id" {
    description = "IDs of security group for ECS"
    value = aws_security_group.this.id
}

output "vpc_id" {
  description = "ID of the VPC"
  value       = data.aws_vpc.default.id
}