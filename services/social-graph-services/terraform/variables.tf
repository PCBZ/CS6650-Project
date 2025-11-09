# Region to deploy into
variable "aws_region" {
  type    = string
  default = "us-west-2"
}

# Shared infrastructure values (passed from root terraform)
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

variable "private_subnet_ids" {
  description = "Private subnet IDs from shared infrastructure"
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

# ECR & ECS settings
variable "ecr_repository_name" {
  type    = string
  default = "social-graph-service"
}

variable "service_name" {
  type    = string
  default = "social-graph"
}

variable "container_port" {
  type    = number
  default = 8085
}

variable "ecs_count" {
  type    = number
  default = 1
}

variable "ecs_desired_count" {
  type    = number
  default = 2
}

# ALB settings
variable "alb_priority" {
  description = "Priority for ALB listener rule"
  type        = number
  default     = 150
}

# IAM roles for ECS tasks
variable "execution_role_arn" {
  description = "ECS task execution role ARN (for pulling images, writing logs)"
  type        = string
}

variable "task_role_arn" {
  description = "ECS task role ARN (for DynamoDB access)"
  type        = string
}

# How long to keep logs
variable "log_retention_days" {
  type    = number
  default = 7
}

# DynamoDB table names
variable "followers_table_name" {
  description = "DynamoDB table name for followers"
  type        = string
  default     = "social-graph-followers"
}

variable "following_table_name" {
  description = "DynamoDB table name for following relationships"
  type        = string
  default     = "social-graph-following"
}

# Database variables (kept for ECS module compatibility, not used by social-graph)
variable "db_host" {
  type    = string
  default = ""
}

variable "db_port" {
  type    = string
  default = ""
}

variable "db_name" {
  type    = string
  default = ""
}

variable "db_password" {
  type      = string
  default   = ""
  sensitive = true
}

# Auto-scaling configuration
variable "min_capacity" {
  description = "Minimum number of ECS tasks"
  type        = number
  default     = 1
}

variable "max_capacity" {
  description = "Maximum number of ECS tasks"
  type        = number
  default     = 10
}

variable "cpu_target_value" {
  description = "Target CPU utilization percentage for scaling"
  type        = number
  default     = 70.0
}

variable "memory_target_value" {
  description = "Target memory utilization percentage for scaling"
  type        = number
  default     = 80.0
}

variable "enable_request_based_scaling" {
  description = "Enable ALB request count based scaling"
  type        = bool
  default     = false
}

variable "request_count_target_value" {
  description = "Target requests per minute per task for scaling"
  type        = number
  default     = 1000
}

variable "service_connect_namespace_arn" {
  description = "ARN of the ECS Service Connect namespace for service discovery"
  type        = string
}
