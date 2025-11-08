variable "service_name" {
    description = "use to name the log group"
    type        = string
}

variable "retention_in_days" {
    description = "how many days to keep the log"
    type        = number
    default     = 7
}