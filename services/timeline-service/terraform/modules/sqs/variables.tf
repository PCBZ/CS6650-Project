variable "service_name" {
  description = "Name of the service (timeline-service)"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "sns_topic_arn" {
  description = "ARN of the SNS topic to subscribe to (from post-service)"
  type        = string
}
