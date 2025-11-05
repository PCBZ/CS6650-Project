# Region to deploy into
variable "aws_region" {
  type    = string
  default = "us-west-2"
}

# ECR & ECS settings
variable "ecr_repository_name" {
  type    = string
  default = "user_service"
}

variable "service_name" {
  type    = string
  default = "user_service"
}

variable "container_port" {
  type    = number
  default = 8080
}

variable "ecs_count" {
  type    = number
  default = 1
}

# ALB settings
variable "alb_priority" {
  description = "Priority for ALB listener rule"
  type        = number
  default     = 100
}

# How long to keep logs
variable "log_retention_days" {
  type    = number
  default = 7
}

# Database settings (shared RDS)
variable "database_name" {
  description = "Name of the database to create in shared RDS instance"
  type        = string
  default     = "userservice"
}

variable "rds_master_username" {
  description = "Master username for shared RDS instance"
  type        = string
  default     = "postgres"
}

variable "rds_master_password" {
  description = "Master password for shared RDS instance"
  type        = string
  sensitive   = true
  # No default value - must be provided via environment variable or tfvars file
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
