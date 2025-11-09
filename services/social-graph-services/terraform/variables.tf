# =============================================================================# Region to deploy into# Region to deploy intovariable "aws_region" {

# AWS Configuration

# =============================================================================variable "aws_region" {



variable "aws_region" {  type    = stringvariable "aws_region" {  description = "AWS region to deploy into"

  description = "AWS region to deploy into"

  type        = string  default = "us-west-2"

  default     = "us-west-2"

}}  type    = string  type        = string



variable "is_windows" {

  description = "Whether running on Windows (for shell command compatibility)"

  type        = bool# Platform detection for shell command compatibility  default = "us-west-2"  default     = "us-west-2"

  default     = false

}variable "is_windows" {



# =============================================================================  description = "Whether running on Windows (for shell command compatibility)"}}

# Shared Infrastructure (passed from root terraform)

# =============================================================================  type        = bool



variable "vpc_id" {  default     = false

  description = "VPC ID from shared infrastructure"

  type        = string}

}

# Platform detection for shell command compatibility# Platform detection for shell command compatibility

variable "vpc_cidr" {

  description = "VPC CIDR block from shared infrastructure"# Shared infrastructure values (passed from root terraform)

  type        = string

}variable "vpc_id" {variable "is_windows" {variable "is_windows" {



variable "public_subnet_ids" {  description = "VPC ID from shared infrastructure"

  description = "Public subnet IDs from shared infrastructure"

  type        = list(string)  type        = string  description = "Whether running on Windows (for shell command compatibility)"  description = "Whether running on Windows (for shell command compatibility)"

}

}

variable "private_subnet_ids" {

  description = "Private subnet IDs from shared infrastructure"  type        = bool  type        = bool

  type        = list(string)

}variable "vpc_cidr" {



variable "alb_listener_arn" {  description = "VPC CIDR block from shared infrastructure"  default     = false  default     = false

  description = "ALB listener ARN from shared infrastructure"

  type        = string  type        = string

}

}}}

variable "alb_arn_suffix" {

  description = "ALB ARN suffix from shared infrastructure"

  type        = string

}variable "public_subnet_ids" {



variable "service_connect_namespace_arn" {  description = "Public subnet IDs from shared infrastructure"

  description = "ECS Service Connect namespace ARN from shared infrastructure"

  type        = string  type        = list(string)# Shared infrastructure values (passed from root terraform)# Shared infrastructure values (passed from root terraform)

}

}

# =============================================================================

# Service Configurationvariable "vpc_id" {variable "execution_role_arn" {

# =============================================================================

variable "private_subnet_ids" {

variable "service_name" {

  description = "Name of the service"  description = "Private subnet IDs from shared infrastructure"  description = "VPC ID from shared infrastructure"  description = "ARN of the ECS task execution role (from shared IAM module)"

  type        = string

  default     = "social_graph_service"  type        = list(string)

}

}  type        = string  type        = string

variable "ecr_repository_name" {

  description = "Name of the ECR repository"

  type        = string

  default     = "social_graph_service"variable "alb_listener_arn" {}}

}

  description = "ALB listener ARN from shared infrastructure"

variable "container_port" {

  description = "Container port for HTTP API"  type        = string

  type        = number

  default     = 8085}

}

variable "vpc_cidr" {variable "task_role_arn" {

variable "ecs_desired_count" {

  description = "Desired number of ECS tasks"variable "alb_arn_suffix" {

  type        = number

  default     = 2  description = "ALB ARN suffix from shared infrastructure"  description = "VPC CIDR block from shared infrastructure"  description = "ARN of the ECS task role for DynamoDB access (from shared IAM module)"

}

  type        = string

variable "log_retention_days" {

  description = "CloudWatch Logs retention days"}  type        = string  type        = string

  type        = number

  default     = 14

}

variable "service_connect_namespace_arn" {}}

# =============================================================================

# ALB Configuration  description = "ECS Service Connect namespace ARN from shared infrastructure"

# =============================================================================

  type        = string

variable "alb_priority" {

  description = "Priority for ALB listener rule"}

  type        = number

  default     = 150variable "public_subnet_ids" {variable "vpc_id" {

}

# ECR & ECS settings

# =============================================================================

# DynamoDB Configurationvariable "ecr_repository_name" {  description = "Public subnet IDs from shared infrastructure"  description = "VPC ID from shared infrastructure"

# =============================================================================

  type    = string

variable "followers_table_name" {

  description = "DynamoDB table name for followers"  default = "social_graph_service"  type        = list(string)  type        = string

  type        = string

  default     = "social-graph-followers"}

}

}}

variable "following_table_name" {

  description = "DynamoDB table name for following relationships"variable "service_name" {

  type        = string

  default     = "social-graph-following"  type    = string

}

  default = "social_graph_service"

# =============================================================================

# Database (RDS) - Optional placeholders}variable "private_subnet_ids" {variable "vpc_cidr" {

# =============================================================================



variable "db_host" {

  description = "Database host (optional, for future RDS integration)"variable "container_port" {  description = "Private subnet IDs from shared infrastructure"  description = "VPC CIDR block from shared infrastructure"

  type        = string

  default     = ""  type    = number

}

  default = 8085  type        = list(string)  type        = string

variable "db_port" {

  description = "Database port (optional, for future RDS integration)"}

  type        = string

  default     = ""}}

}

variable "ecs_desired_count" {

variable "db_name" {

  description = "Database name (optional, for future RDS integration)"  type    = number

  type        = string

  default     = ""  default = 2

}

}variable "alb_listener_arn" {variable "public_subnet_ids" {

variable "db_password" {

  description = "Database password (optional, for future RDS integration)"

  type        = string

  default     = ""variable "log_retention_days" {  description = "ALB listener ARN from shared infrastructure"  description = "Public subnet IDs from shared infrastructure"

  sensitive   = true

}  type    = number



# =============================================================================  default = 14  type        = string  type        = list(string)

# Auto-Scaling Configuration

# =============================================================================}



variable "min_capacity" {}}

  description = "Minimum number of tasks for auto-scaling"

  type        = number# ALB settings

  default     = 1

}variable "alb_priority" {



variable "max_capacity" {  description = "Priority for ALB listener rule"

  description = "Maximum number of tasks for auto-scaling"

  type        = number  type        = numbervariable "alb_arn_suffix" {variable "alb_listener_arn" {

  default     = 10

}  default     = 150



variable "cpu_target_value" {}  description = "ALB ARN suffix from shared infrastructure"  description = "ALB listener ARN from shared infrastructure"

  description = "Target CPU utilization percentage for auto-scaling"

  type        = number

  default     = 70

}# DynamoDB settings  type        = string  type        = string



variable "memory_target_value" {variable "followers_table_name" {

  description = "Target memory utilization percentage for auto-scaling"

  type        = number  description = "DynamoDB table name for followers"}}

  default     = 80

}  type        = string



variable "enable_request_based_scaling" {  default     = "social-graph-followers"

  description = "Enable request-based auto-scaling"

  type        = bool}

  default     = true

}variable "service_connect_namespace_arn" {variable "alb_arn_suffix" {



variable "request_count_target_value" {variable "following_table_name" {

  description = "Target request count per task for request-based scaling"

  type        = number  description = "DynamoDB table name for following relationships"  description = "ECS Service Connect namespace ARN from shared infrastructure"  description = "ALB ARN suffix from shared infrastructure"

  default     = 1000

}  type        = string


  default     = "social-graph-following"  type        = string  type        = string

}

}}

# Database placeholders (optional - for RDS if needed)

variable "db_host" {

  type    = string

  default = ""# ECR & ECS settingsvariable "service_connect_namespace_arn" {

}

variable "ecr_repository_name" {  description = "ECS Service Connect namespace ARN from shared infrastructure"

variable "db_port" {

  type    = string  type    = string  type        = string

  default = ""

}  default = "social_graph_service"}



variable "db_name" {}

  type    = string

  default = ""variable "common_tags" {

}

variable "service_name" {  description = "Common tags to apply to resources"

variable "db_password" {

  type      = string  type    = string  type        = map(string)

  default   = ""

  sensitive = true  default = "social_graph_service"  default     = {}

}

}}

# Auto-scaling settings

variable "min_capacity" {

  type    = number

  default = 1variable "container_port" {variable "container_port" {

}

  type    = number  description = "Container port to expose"

variable "max_capacity" {

  type    = number  default = 50052  type        = number

  default = 4

}}  default     = 8080



variable "cpu_target_value" {}

  type    = number

  default = 70variable "ecs_desired_count" {

}

  type    = numbervariable "ecs_desired_count" {

variable "memory_target_value" {

  type    = number  default = 2  description = "Number of ECS tasks to run"

  default = 80

}}  type        = number



variable "enable_request_based_scaling" {  default     = 2

  type    = bool

  default = truevariable "log_retention_days" {}

}

  type    = number

variable "request_count_target_value" {

  type    = number  default = 14variable "log_retention_days" {

  default = 1000

}}  description = "CloudWatch Logs retention days"


  type        = number

# ALB settings  default     = 14

variable "alb_priority" {}

  description = "Priority for ALB listener rule"

  type        = number# ALB settings

  default     = 150variable "alb_priority" {

}  description = "Priority for ALB listener rule"

  type        = number

# DynamoDB settings  default     = 150

variable "followers_table_name" {}

  description = "DynamoDB table name for followers"

  type        = stringvariable "ecr_repository_name" {

  default     = "social-graph-followers"  description = "Name of the ECR repository for this service"

}  type        = string

  default     = "social-graph-service"

variable "following_table_name" {}

  description = "DynamoDB table name for following relationships"

  type        = stringvariable "service_name" {

  default     = "social-graph-following"  description = "Service name used for ECS, ALB, and logs"

}  type        = string

  default     = "social-graph"

# Database placeholders (optional - for RDS if needed)}

variable "db_host" {

  type    = stringvariable "dynamodb_table_name" {

  default = ""  description = "DynamoDB table name for followers"

}  type        = string

  default     = "social-graph-followers"

variable "db_port" {}

  type    = string

  default = ""variable "dynamodb_following_table_name" {

}  description = "DynamoDB table name for following relationships"

  type        = string

variable "db_name" {  default     = "social-graph-following"

  type    = string}

  default = ""

}# Database placeholders (optional)

variable "db_host" {

variable "db_password" {  type        = string

  type      = string  default     = ""

  default   = ""}

  sensitive = true

}variable "db_port" {

  type        = string

# Auto-scaling settings  default     = ""

variable "min_capacity" {}

  type    = number

  default = 1variable "db_name" {

}  type        = string

  default     = ""

variable "max_capacity" {}

  type    = number

  default = 4variable "db_password" {

}  type        = string

  default     = ""

variable "cpu_target_value" {  sensitive   = true

  type    = number}

  default = 70

}# Auto-scaling defaults

variable "min_capacity" {

variable "memory_target_value" {  type    = number

  type    = number  default = 1

  default = 80}

}

variable "max_capacity" {

variable "enable_request_based_scaling" {  type    = number

  type    = bool  default = 4

  default = true}

}

variable "cpu_target_value" {

variable "request_count_target_value" {  type    = number

  type    = number  default = 70

  default = 1000}

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

