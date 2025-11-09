output "ecs_task_execution_role_arn" {
  description = "ARN of the ECS task execution role (shared by all services)"
  value       = aws_iam_role.ecs_task_execution_role.arn
}

output "ecs_task_execution_role_name" {
  description = "Name of the ECS task execution role"
  value       = aws_iam_role.ecs_task_execution_role.name
}

output "social_graph_task_role_arn" {
  description = "ARN of the Social Graph Service task role (for DynamoDB access)"
  value       = aws_iam_role.social_graph_task_role.arn
}

output "social_graph_task_role_name" {
  description = "Name of the Social Graph Service task role"
  value       = aws_iam_role.social_graph_task_role.name
}
