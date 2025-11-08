variable "table_name" {
  description = "Name of the DynamoDB table for posts"
  type        = string
  default     = "posts"
}

variable "environment" {
  description = "Environment name for tagging"
  type        = string
  default     = "development"
}

