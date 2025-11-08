output "cluster_name" {
    description = "ECS cluster name"
    value       = aws_ecs_cluster.this.name
}

output "service_name" {
    description = "ECS service name"
    value       = aws_ecs_service.this.name
}

output "autoscaling_target_resource_id" {
  description = "Resource ID of the autoscaling target"
  value       = aws_appautoscaling_target.ecs_target.resource_id
}

output "autoscaling_target_scalable_dimension" {
  description = "Scalable dimension of the autoscaling target"
  value       = aws_appautoscaling_target.ecs_target.scalable_dimension
}