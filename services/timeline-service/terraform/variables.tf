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
  default = "timeline-service"
}

variable "service_name" {
  type    = string
  default = "timeline-service"
}

variable "container_port" {
  type    = number
  default = 8082
}

variable "ecs_count" {
  type    = number
  default = 1
}

# ALB settings
variable "alb_priority" {
  description = "Priority for ALB listener rule"
  type        = number
  default     = 110
}

# How long to keep logs
variable "log_retention_days" {
  type    = number
  default = 7
}

# DynamoDB settings
variable "dynamodb_table_name" {
  description = "DynamoDB table name for timeline cache"
  type        = string
}

variable "enable_pitr" {
  description = "Enable Point-in-Time Recovery for DynamoDB"
  type        = bool
  default     = false
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
}

# SQS settings
variable "sqs_queue_url" {
  description = "SQS queue URL for async feed writes"
  type        = string
}

# Service URLs for gRPC communication
variable "post_service_url" {
  description = "Post Service URL for gRPC communication"
  type        = string
}

variable "social_graph_service_url" {
  description = "Social Graph Service URL for gRPC communication"
  type        = string
}

variable "user_service_url" {
  description = "User Service URL for gRPC communication"
  type        = string
}

# Timeline Strategy Configuration
variable "fanout_strategy" {
  type        = string
  description = "Timeline fanout strategy: push, pull, or hybrid"
  default     = "hybrid"
}

variable "celebrity_threshold" {
  type        = number
  description = "Follower count threshold for hybrid strategy"
  default     = 50000
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
