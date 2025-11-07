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

output "alb_dns_name" {
  description = "DNS name of the load balancer (public endpoint)"
  value       = var.alb_dns_name
}

output "service_endpoint" {
  description = "Public endpoint to access the web service"
  value       = "http://${var.alb_dns_name}"
}
