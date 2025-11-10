output "cluster_name" {
  description = "ECS cluster name"
  value       = aws_ecs_cluster.main.name
}

output "service_name" {
  description = "ECS service name"
  value       = aws_ecs_service.app.name
}

output "autoscaling_target_resource_id" {
  description = "Auto Scaling target resource ID"
  value       = aws_appautoscaling_target.ecs_target.resource_id
}

output "cpu_scaling_policy_arn" {
  description = "CPU-based scaling policy ARN"
  value       = aws_appautoscaling_policy.scale_up_cpu.arn
}

output "memory_scaling_policy_arn" {
  description = "Memory-based scaling policy ARN"
  value       = aws_appautoscaling_policy.scale_up_memory.arn
}

output "high_cpu_alarm_arn" {
  description = "High CPU CloudWatch alarm ARN"
  value       = aws_cloudwatch_metric_alarm.high_cpu.arn
}

output "high_memory_alarm_arn" {
  description = "High memory CloudWatch alarm ARN"
  value       = aws_cloudwatch_metric_alarm.high_memory.arn
}

output "service_connect_http_endpoint" {
  description = "Service Connect HTTP endpoint (DNS name)"
  value       = var.service_name
}

output "service_connect_grpc_endpoint" {
  description = "Service Connect gRPC endpoint (DNS name:port)"
  value       = "${var.service_name}-grpc"
}
