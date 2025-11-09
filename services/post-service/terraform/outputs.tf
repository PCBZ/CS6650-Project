output "sns_topic_arn" {
  description = "ARN of the SNS topic (for timeline-service to subscribe)"
  value       = local.sns_topic_arn
}

output "security_group_id" {
  description = "Security group ID for the post service"
  value       = aws_security_group.app.id
}

output "target_group_arn" {
  description = "Target group ARN for the post service"
  value       = aws_lb_target_group.service.arn
}

output "ecs_service_name" {
  description = "ECS service name for the post service"
  value       = module.ecs.service_name
}
