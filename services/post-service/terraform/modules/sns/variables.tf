variable "service_name" {
    description = "name of the service"
    type        = string
}

variable "environment" {
    description = "environment name"
    type        = string
    default     = "dev"
}

variable "sqs_queue_arn" {
    description = "ARN of the SQS queue to subscribe to SNS"
    type        = string
}