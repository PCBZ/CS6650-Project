output "vpc_id" {
  description = "ID of the VPC"
  value       = module.network.vpc_id
}

output "vpc_cidr" {
  description = "CIDR block of the VPC"
  value       = module.network.vpc_cidr
}

output "public_subnet_ids" {
  description = "IDs of the public subnets"
  value       = module.network.public_subnet_ids
}

output "private_subnet_ids" {
  description = "IDs of the private subnets"
  value       = module.network.private_subnet_ids
}

output "alb_arn" {
  description = "ARN of the Application Load Balancer"
  value       = module.alb.alb_arn
}

output "alb_arn_suffix" {
  description = "ARN suffix of the Application Load Balancer (for CloudWatch metrics)"
  value       = module.alb.alb_arn_suffix
}

output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = module.alb.alb_dns_name
}

output "alb_listener_arn" {
  description = "ARN of the ALB listener"
  value       = module.alb.listener_arn
}

output "alb_security_group_id" {
  description = "ID of the ALB security group"
  value       = module.network.alb_security_group_id
}

# RDS Outputs (Simple PostgreSQL)
output "rds_endpoint" {
  description = "RDS instance endpoint"
  value       = module.rds.db_endpoint
}

output "rds_address" {
  description = "RDS instance address"
  value       = module.rds.db_address
}

output "rds_port" {
  description = "RDS instance port"
  value       = module.rds.db_port
}

output "rds_security_group_id" {
  description = "RDS security group ID"
  value       = module.rds.security_group_id
}

# User Service Outputs
output "user_service_ecr_repository_url" {
  description = "ECR repository URL for user service"
  value       = module.user_service.ecr_repository_url
}

output "user_service_ecs_service_name" {
  description = "ECS service name for user service"
  value       = module.user_service.ecs_service_name
}

output "user_service_target_group_arn" {
  description = "Target group ARN for user service"
  value       = module.user_service.target_group_arn
}

# Web Service Outputs
output "web_service_ecr_repository_url" {
  description = "ECR repository URL for web service"
  value       = module.web_service.ecr_repository_url
}

output "web_service_ecs_service_name" {
  description = "ECS service name for web service"
  value       = module.web_service.ecs_service_name
}

output "web_service_target_group_arn" {
  description = "Target group ARN for web service"
  value       = module.web_service.target_group_arn
}

# Service Connect namespace
output "service_connect_namespace_arn" {
  description = "ARN of the Service Connect namespace"
  value       = module.network.service_connect_namespace_arn
}

# Timeline Service Outputs
output "timeline_service_ecr_repository_url" {
  description = "ECR repository URL for timeline service"
  value       = module.timeline_service.ecr_repository_url
}

output "timeline_service_ecs_service_name" {
  description = "ECS service name for timeline service"
  value       = module.timeline_service.ecs_service_name
}

output "timeline_service_target_group_arn" {
  description = "Target group ARN for timeline service"
  value       = module.timeline_service.target_group_arn
}

output "timeline_service_dynamodb_table_name" {
  description = "DynamoDB table name for timeline service"
  value       = module.timeline_service.dynamodb_table_name
}

output "timeline_service_dynamodb_table_arn" {
  description = "DynamoDB table ARN for timeline service"
  value       = module.timeline_service.dynamodb_table_arn
}

output "timeline_service_connect_endpoint" {
  description = "Service Connect HTTP endpoint for timeline service"
  value       = module.timeline_service.service_connect_http_endpoint
}

# Social Graph Service Outputs
output "social_graph_service_ecr_repository_url" {
  description = "ECR repository URL for social graph service"
  value       = module.social_graph_service.ecr_repository_url
}

output "social_graph_service_ecs_service_name" {
  description = "ECS service name for social graph service"
  value       = module.social_graph_service.ecs_service_name
}

output "social_graph_service_target_group_arn" {
  description = "Target group ARN for social graph service"
  value       = module.social_graph_service.target_group_arn
}

output "social_graph_service_security_group_id" {
  description = "Security group ID for social graph service"
  value       = module.social_graph_service.security_group_id
}

output "social_graph_service_followers_table_name" {
  description = "DynamoDB followers table name for social graph service"
  value       = module.social_graph_service.followers_table_name
}

output "social_graph_service_followers_table_arn" {
  description = "DynamoDB followers table ARN for social graph service"
  value       = module.social_graph_service.followers_table_arn
}

output "social_graph_service_following_table_name" {
  description = "DynamoDB following table name for social graph service"
  value       = module.social_graph_service.following_table_name
}

output "social_graph_service_following_table_arn" {
  description = "DynamoDB following table ARN for social graph service"
  value       = module.social_graph_service.following_table_arn
}

output "social_graph_service_connect_endpoint" {
  description = "Service Connect gRPC endpoint for social graph service"
  value       = module.social_graph_service.service_connect_grpc_endpoint
}