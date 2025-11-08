
# region
variable "aws_region" {
  type = string
  default = "us-west-2"
}

# network module
variable "service_name" {
    type    = string
    default = "post-service"
}

variable "container_port" {
    type    = number
    default = 8082
}

# logging module
variable "log_retention_days" {
  type    = number
  default = 7
}

## ecr module
variable "repository_name" {
    type    = string
    default = "post_service"
}

## ecs count
variable "ecs_count" {
    type    = number
    default = 1
}

# SNS/SQS configuration
variable "environment" {
  type    = string
  default = "dev"
}

# Application configuration
variable "post_strategy" {
  description = "Post strategy: 'push', 'pull', or 'hybrid'"
  type        = string
  default     = "hybrid"
}

variable "dynamo_table" {
  description = "DynamoDB table name for posts"
  type        = string
  default     = "posts-table"
}

variable "social_graph_url" {
  description = "Social graph service URL"
  type        = string
  default     = "localhost:50052"
}