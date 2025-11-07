variable "service_name" {
  description = "Name of the service"
  type        = string
}

variable "retention_in_days" {
  description = "Log retention period in days"
  type        = number
  default     = 7
}
