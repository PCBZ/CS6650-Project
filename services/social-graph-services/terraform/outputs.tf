output "ecs_cluster_name" {
  description = "ECS cluster name (from ecs module)"
  value       = module.ecs.cluster_name
}

output "ecs_service_name" {
  description = "ECS service name (from ecs module)"
  value       = module.ecs.service_name
}

output "dynamodb_table_name" {
  description = "DynamoDB table for followers"
  value       = aws_dynamodb_table.followers.name
}

output "dynamodb_table_arn" {
  description = "DynamoDB table ARN for followers"
  value       = aws_dynamodb_table.followers.arn
}

output "dynamodb_following_table_name" {
  description = "DynamoDB table name for following relationships"
  value       = aws_dynamodb_table.following.name
}

output "dynamodb_following_table_arn" {
  description = "DynamoDB table ARN for following relationships"
  value       = aws_dynamodb_table.following.arn
}

output "iam_task_role_arn" {
  description = "IAM role ARN for ECS task role (from shared IAM module)"
  value       = var.task_role_arn
}

output "iam_execution_role_arn" {
  description = "IAM role ARN for ECS execution role (from shared IAM module)"
  value       = var.execution_role_arn
}

output "ecr_repository_url" {
  description = "ECR repository URL"
  value       = module.ecr.repository_url
}

output "target_group_arn" {
  description = "Target group ARN"
  value       = aws_lb_target_group.service.arn
}

output "security_group_id" {
  description = "Security group ID for the service"
  value       = aws_security_group.app.id
}
