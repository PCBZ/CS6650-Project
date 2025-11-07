variable "service_name" {
  description = "Name of the service"
  type        = string
}

variable "image" {
  description = "Docker image to run"
  type        = string
}

variable "cpu" {
  description = "CPU units for the task"
  type        = string
  default     = "256"
}

variable "memory" {
  description = "Memory for the task"
  type        = string
  default     = "512"
}

variable "execution_role_arn" {
  description = "ARN of the execution role"
  type        = string
}

variable "task_role_arn" {
  description = "ARN of the task role"
  type        = string
}

variable "log_group_name" {
  description = "Name of the CloudWatch log group"
  type        = string
}

variable "region" {
  description = "AWS region"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "grpc_server_address" {
  description = "gRPC server address (Service Connect DNS name)"
  type        = string
  default     = "user-service-grpc:50051"
}

variable "service_connect_namespace_arn" {
  description = "ARN of the Service Connect namespace"
  type        = string
}
