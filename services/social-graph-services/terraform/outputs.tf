output "ecs_cluster_name" {output "ecs_cluster_name" {

  description = "Name of the created ECS cluster"  description = "ECS cluster name (from ecs module)"

  value       = module.ecs.cluster_name  value       = module.ecs.cluster_name

}}



output "ecs_service_name" {output "ecs_service_name" {

  description = "Name of the running ECS service"  description = "ECS service name (from ecs module)"

  value       = module.ecs.service_name  value       = module.ecs.service_name

}}



output "ecr_repository_url" {output "dynamodb_table_name" {

  description = "ECR repository URL"  description = "DynamoDB table for followers"

  value       = module.ecr.repository_url  value       = aws_dynamodb_table.followers.name

}}



output "target_group_arn" {output "dynamodb_table_arn" {

  description = "ALB target group ARN for this service"  description = "DynamoDB table ARN for followers"

  value       = aws_lb_target_group.service.arn  value       = aws_dynamodb_table.followers.arn

}}



output "security_group_id" {output "dynamodb_following_table_name" {

  description = "Security group ID for this service"  description = "DynamoDB table name for following relationships"

  value       = aws_security_group.app.id  value       = aws_dynamodb_table.following.name

}}



output "service_connect_grpc_endpoint" {output "dynamodb_following_table_arn" {

  description = "Service Connect gRPC endpoint for internal communication"  description = "DynamoDB table ARN for following relationships"

  value       = module.ecs.service_connect_grpc_endpoint  value       = aws_dynamodb_table.following.arn

}}



output "followers_table_name" {output "iam_task_role_arn" {

  description = "DynamoDB table name for followers"  description = "IAM role ARN for ECS task role (from shared IAM module)"

  value       = aws_dynamodb_table.followers.name  value       = var.task_role_arn

}}



output "followers_table_arn" {output "iam_execution_role_arn" {

  description = "DynamoDB table ARN for followers"  description = "IAM role ARN for ECS execution role (from shared IAM module)"

  value       = aws_dynamodb_table.followers.arn  value       = var.execution_role_arn

}}



output "following_table_name" {output "ecr_repository_url" {

  description = "DynamoDB table name for following"  description = "ECR repository URL"

  value       = aws_dynamodb_table.following.name  value       = module.ecr.repository_url

}}



output "following_table_arn" {output "target_group_arn" {

  description = "DynamoDB table ARN for following"  description = "Target group ARN"

  value       = aws_dynamodb_table.following.arn  value       = aws_lb_target_group.service.arn

}}


output "security_group_id" {
  description = "Security group ID for the service"
  value       = aws_security_group.app.id
}
