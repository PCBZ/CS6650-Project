variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "us-west-2"
}

# Platform detection for shell command compatibility
variable "is_windows" {
  description = "Whether running on Windows (for shell command compatibility)"
  type        = bool
  default     = false
}

# Shared infrastructure values (passed from root terraform)
variable "execution_role_arn" {
  description = "ARN of the ECS task execution role (from shared IAM module)"
  type        = string
}

variable "task_role_arn" {
  description = "ARN of the ECS task role for DynamoDB access (from shared IAM module)"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID from shared infrastructure"
  type        = string
}

variable "vpc_cidr" {
  description = "VPC CIDR block from shared infrastructure"
  type        = string
}

variable "public_subnet_ids" {
  description = "Public subnet IDs from shared infrastructure"
  type        = list(string)
}

variable "alb_listener_arn" {
  description = "ALB listener ARN from shared infrastructure"
  type        = string
}

variable "alb_arn_suffix" {
  description = "ALB ARN suffix from shared infrastructure"
  type        = string
}

variable "service_connect_namespace_arn" {
  description = "ECS Service Connect namespace ARN from shared infrastructure"
  type        = string
}

variable "common_tags" {
  description = "Common tags to apply to resources"
  type        = map(string)
  default     = {}
}

variable "container_port" {
  description = "Container port to expose"
  type        = number
  default     = 8080
}

variable "ecs_desired_count" {
  description = "Number of ECS tasks to run"
  type        = number
  default     = 2
}

variable "log_retention_days" {
  description = "CloudWatch Logs retention days"
  type        = number
  default     = 14
}

# ALB settings
variable "alb_priority" {
  description = "Priority for ALB listener rule"
  type        = number
  default     = 150
}

variable "ecr_repository_name" {
  description = "Name of the ECR repository for this service"
  type        = string
  default     = "social-graph-service"
}

variable "service_name" {
  description = "Service name used for ECS, ALB, and logs"
  type        = string
  default     = "social-graph"
}

variable "dynamodb_table_name" {
  description = "DynamoDB table name for followers"
  type        = string
  default     = "social-graph-followers"
}

variable "dynamodb_following_table_name" {
  description = "DynamoDB table name for following relationships"
  type        = string
  default     = "social-graph-following"
}

# Database placeholders (optional)
variable "db_host" {
  type        = string
  default     = ""
}

variable "db_port" {
  type        = string
  default     = ""
}

variable "db_name" {
  type        = string
  default     = ""
}

variable "db_password" {
  type        = string
  default     = ""
  sensitive   = true
}

# Auto-scaling defaults
variable "min_capacity" {
  type    = number
  default = 1
}

variable "max_capacity" {
  type    = number
  default = 4
}

variable "cpu_target_value" {
  type    = number
  default = 70
}

variable "memory_target_value" {
  type    = number
  default = 80
}

variable "enable_request_based_scaling" {
  type    = bool
  default = false
}

variable "request_count_target_value" {
  type    = number
  default = 1000
}

