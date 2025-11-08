# Cluster
variable "service_name" {
    description = "Base name for ECS resources"
    type        = string
}

# Task Definition
variable "cpu" {
    description = "vCPU units"
    type        = string
    default     = "256"
}

variable "memory" {
    description = "Memory (MiB)"
    type        = string
    default     = "512"
}
 
variable "execution_role_arn" {
    description = "ECS Task Execution Role ARN"
    type        = string
}

variable "task_role_arn" {
    description = "IAM Role ARN for app permissions"
    type        = string
}

variable "image" {
    description = "ECR image URI (with tag)"
    type        = string
}

variable "container_port" {
    description = "Port the app listens on"
    type        = number
    default     = null
}

variable "log_group_name" {
    description = "Name of the CloudWatch Group"
    type        = string
}

variable "region" {
    description = "AWS region (for awslogs driver)"
    type        = string
}

# ECS
variable "ecs_count" {
    description = "Desired number of services"
    type        = number
    default     = 1
}

variable "subnet_ids" {
    description = "Subnet for FARGATE tasks"
    type        = list(string)
}

variable "security_group_ids" {
    description = "SGs for FARGATE tasks"
    type        = list(string)
}


#ALB
variable "target_group_arn" {
  description = "ARN of the target group"
  type        = string
  default     = null
}

# Auto Scaling variables
variable "min_capacity" {
  description = "Minimum number of ECS tasks"
  type        = number
  default     = 2
}

variable "max_capacity" {
  description = "Maximum number of ECS tasks"
  type        = number
  default     = 4
}

variable "target_cpu_utilization" {
  description = "Target CPU utilization percentage"
  type        = number
  default     = 70
}

variable "scale_out_cooldown" {
  description = "Scale-out cooldown period in seconds"
  type        = number
  default     = 300
}

variable "scale_in_cooldown" {
  description = "Scale-in cooldown period in seconds"
  type        = number
  default     = 300
}

# SQS-based Scaling configuration
variable "scaling_metric" {
  description = "Scaling metric: 'cpu' or 'sqs'"
  type        = string
  default     = "cpu"
}

variable "sqs_queue_name" {
  description = "Name of the SQS queue for SQS-based scaling"
  type        = string
  default     = null
}

variable "sqs_target_value" {
  description = "Target number of messages in queue for scaling"
  type        = number
  default     = 5
}

variable "environment_variables" {
  description = "Environment variables for the container"
  type        = list(object({
    name  = string
    value = string
  }))
  default = []
}