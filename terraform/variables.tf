variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-west-2"
}

variable "aws_account_id" {
  description = "AWS account ID"
  type        = string
  default     = "892825672262"
}

variable "is_windows" {
  description = "Whether running on Windows (for shell command compatibility)"
  type        = bool
  default     = false  # Mac/Linux users should keep this false; Windows users set to true
}

variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "cs6650-project"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "Availability zones"
  type        = list(string)
  default     = ["us-west-2a", "us-west-2b", "us-west-2c"]
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets"
  type        = list(string)
  default     = ["10.0.10.0/24", "10.0.20.0/24", "10.0.30.0/24"]
}

# RDS Configuration
variable "rds_master_username" {
  description = "Master username for RDS PostgreSQL instance"
  type        = string
  default     = "postgres"
}

variable "rds_master_password" {
  description = "Master password for RDS PostgreSQL instance"
  type        = string
  sensitive   = true
  # No default value - must be provided via environment variable or tfvars file
}

variable "rds_instance_class" {
  description = "RDS PostgreSQL instance class"
  type        = string
  default     = "db.t3.micro"
}

variable "rds_backup_retention_period" {
  description = "Backup retention period in days"
  type        = number
  default     = 7
}

# User Service Configuration
variable "user_service_database_name" {
  description = "Database name for user service"
  type        = string
  default     = "userdb"
}

variable "user_service_ecs_count" {
  description = "Number of ECS tasks for user service"
  type        = number
  default     = 2
}

variable "user_service_min_capacity" {
  description = "Minimum number of tasks for user service auto-scaling"
  type        = number
  default     = 1
}

variable "user_service_max_capacity" {
  description = "Maximum number of tasks for user service auto-scaling"
  type        = number
  default     = 10
}

variable "user_service_cpu_target_value" {
  description = "Target CPU utilization percentage for user service scaling"
  type        = number
  default     = 70
}

variable "user_service_memory_target_value" {
  description = "Target memory utilization percentage for user service scaling"
  type        = number
  default     = 80
}

variable "user_service_enable_request_based_scaling" {
  description = "Enable request-based auto-scaling for user service"
  type        = bool
  default     = true
}

variable "user_service_request_count_target_value" {
  description = "Target request count per task for user service scaling"
  type        = number
  default     = 1000
}

# Web Service Configuration
variable "web_service_ecs_count" {
  description = "Number of ECS tasks for web service"
  type        = number
  default     = 2
}

variable "web_service_user_service_url" {
  description = "URL of the user service for web service to connect to"
  type        = string
  default     = "http://user-service:8080"
}

variable "web_service_min_capacity" {
  description = "Minimum number of tasks for web service auto-scaling"
  type        = number
  default     = 1
}

variable "web_service_max_capacity" {
  description = "Maximum number of tasks for web service auto-scaling"
  type        = number
  default     = 10
}

variable "web_service_cpu_target_value" {
  description = "Target CPU utilization percentage for web service scaling"
  type        = number
  default     = 70
}

variable "web_service_memory_target_value" {
  description = "Target memory utilization percentage for web service scaling"
  type        = number
  default     = 80
}

variable "web_service_enable_request_based_scaling" {
  description = "Enable request-based auto-scaling for web service"
  type        = bool
  default     = true
}

variable "web_service_request_count_target_value" {
  description = "Target request count per task for web service scaling"
  type        = number
  default     = 1000
}

# Social Graph Service Configuration
variable "social_graph_ecs_count" {
  description = "Number of ECS tasks for social graph service"
  type        = number
  default     = 2
}

variable "social_graph_min_capacity" {
  description = "Minimum number of tasks for social graph service auto-scaling"
  type        = number
  default     = 1
}

variable "social_graph_max_capacity" {
  description = "Maximum number of tasks for social graph service auto-scaling"
  type        = number
  default     = 10
}

variable "social_graph_cpu_target_value" {
  description = "Target CPU utilization percentage for social graph service scaling"
  type        = number
  default     = 70
}

variable "social_graph_memory_target_value" {
  description = "Target memory utilization percentage for social graph service scaling"
  type        = number
  default     = 80
}

variable "social_graph_enable_request_based_scaling" {
  description = "Enable request-based auto-scaling for social graph service"
  type        = bool
  default     = true
}

variable "social_graph_request_count_target_value" {
  description = "Target request count per task for social graph service scaling"
  type        = number
  default     = 1000
}