variable "service_name" {
  description = "Name of the service"
  type        = string
}

variable "retention_in_days" {
  description = "Number of days to retain logs"
  type        = number
  default     = 7
}
