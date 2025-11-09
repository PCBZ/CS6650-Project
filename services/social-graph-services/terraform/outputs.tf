output "ecs_cluster_name" {
  description = "Name of the created ECS cluster"
  value       = module.ecs.cluster_name
}

output "ecs_service_name" {
  description = "Name of the running ECS service"
  value       = module.ecs.service_name
}

output "ecr_repository_url" {
  description = "ECR repository URL"
  value       = module.ecr.repository_url
}

output "target_group_arn" {
  description = "ALB target group ARN for this service"
  value       = aws_lb_target_group.service.arn
}

output "security_group_id" {
  description = "Security group ID for this service"
  value       = aws_security_group.app.id
}

output "service_connect_http_endpoint" {
  description = "Service Connect HTTP endpoint for internal communication"
  value       = module.ecs.service_connect_http_endpoint
}

output "service_connect_grpc_endpoint" {
  description = "Service Connect gRPC endpoint for internal communication"
  value       = module.ecs.service_connect_grpc_endpoint
}

output "dynamodb_followers_table_name" {
  description = "DynamoDB followers table name"
  value       = aws_dynamodb_table.followers.name
}

output "dynamodb_followers_table_arn" {
  description = "DynamoDB followers table ARN"
  value       = aws_dynamodb_table.followers.arn
}

output "dynamodb_following_table_name" {
  description = "DynamoDB following table name"
  value       = aws_dynamodb_table.following.name
}

output "dynamodb_following_table_arn" {
  description = "DynamoDB following table ARN"
  value       = aws_dynamodb_table.following.arn
}
