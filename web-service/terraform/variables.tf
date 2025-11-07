# Region to deploy into
variable "aws_region" {
  type    = string
  default = "us-west-2"
}

# Shared infrastructure values (passed from root terraform)
variable "vpc_id" {
  description = "ID of the VPC"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block of the VPC"
  type        = string
}

variable "public_subnet_ids" {
  description = "IDs of the public subnets"
  type        = list(string)
}

variable "alb_listener_arn" {
  description = "ARN of the ALB listener"
  type        = string
}

variable "alb_arn_suffix" {
  description = "ARN suffix of the ALB (for CloudWatch metrics)"
  type        = string
}

variable "alb_dns_name" {
  description = "DNS name of the ALB"
  type        = string
}

# ECR & ECS settings
variable "ecr_repository_name" {
  type    = string
  default = "web_service"
}

variable "service_name" {
  type    = string
  default = "web_service"
}

variable "container_port" {
  type    = number
  default = 3000
}

variable "ecs_count" {
  type    = number
  default = 1
}

# ALB settings
variable "alb_priority" {
  description = "Priority for ALB listener rule (lower number = higher priority)"
  type        = number
  default     = 200  # Lower priority than user-service since this is catch-all
}

# How long to keep logs
variable "log_retention_days" {
  type    = number
  default = 7
}

# User Service URL (internal communication)
variable "user_service_url" {
  description = "Internal URL for user-service communication"
  type        = string
  default     = "http://user-service:8080"
}

# User Service gRPC endpoint
variable "user_service_grpc_host" {
  description = "gRPC endpoint for user-service (host:port)"
  type        = string
  default     = "user-service:50051"
}

# Timeline Service URL (internal communication)
variable "timeline_service_url" {
  description = "Internal URL for timeline-service communication"
  type        = string
  default     = "http://timeline-service:8084"
}

# User Service Security Group ID (for gRPC access)
variable "user_service_security_group_id" {
  description = "Security group ID of user-service to allow gRPC traffic"
  type        = string
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
