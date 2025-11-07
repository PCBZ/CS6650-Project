output "ecr_repository_url" {
  description = "URL of the ECR repository"
  value       = module.ecr.repository_url
}

output "cluster_name" {
  description = "Name of the ECS cluster"
  value       = module.ecs.cluster_name
}

output "task_definition_arn" {
  description = "ARN of the task definition"
  value       = module.ecs.task_definition_arn
}

output "task_definition_family" {
  description = "Family of the task definition"
  value       = module.ecs.task_definition_family
}

output "security_group_id" {
  description = "ID of the security group"
  value       = module.ecs.security_group_id
}

output "run_task_command" {
  description = "AWS CLI command to run the gRPC test client"
  value = <<-EOT
    aws ecs run-task \
      --cluster ${module.ecs.cluster_name} \
      --task-definition ${module.ecs.task_definition_family} \
      --launch-type FARGATE \
      --network-configuration "awsvpcConfiguration={subnets=[${join(",", data.terraform_remote_state.shared_infra.outputs.public_subnet_ids)}],securityGroups=[${module.ecs.security_group_id}],assignPublicIp=ENABLED}" \
      --region ${var.aws_region}
  EOT
}
