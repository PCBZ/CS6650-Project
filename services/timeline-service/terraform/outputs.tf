output "ecr_repository_url" {
  value       = module.ecr.repository_url
  description = "ECR repository URL for the timeline service"
}

output "ecs_cluster_name" {
  value       = module.ecs.cluster_name
  description = "ECS cluster name"
}

output "ecs_service_name" {
  value       = module.ecs.service_name
  description = "ECS service name"
}

output "security_group_id" {
  value       = aws_security_group.app.id
  description = "Security group ID for the timeline service"
}

output "target_group_arn" {
  value       = aws_lb_target_group.service.arn
  description = "Target group ARN for the timeline service"
}

output "log_group_name" {
  value       = module.logging.log_group_name
  description = "CloudWatch log group name"
}
