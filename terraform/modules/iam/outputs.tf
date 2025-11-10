output "ecs_task_execution_role_arn" {
  description = "ARN of the ECS task execution role"
  value       = aws_iam_role.ecs_task_execution_role.arn
}

output "post_service_task_role_arn" {
  description = "ARN of the post service task role"
  value       = aws_iam_role.post_service_task_role.arn
}

output "timeline_service_task_role_arn" {
  description = "ARN of the timeline service task role"
  value       = aws_iam_role.timeline_service_task_role.arn
}

output "social_graph_service_task_role_arn" {
  description = "ARN of the social graph service task role"
  value       = aws_iam_role.social_graph_service_task_role.arn
}
