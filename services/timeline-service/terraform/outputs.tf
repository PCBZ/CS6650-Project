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

output "dynamodb_table_name" {
  description = "DynamoDB table name for timeline cache"
  value       = aws_dynamodb_table.posts.name
}

output "dynamodb_table_arn" {
  description = "DynamoDB table ARN"
  value       = aws_dynamodb_table.posts.arn
}
