variable "service_name" {
    description = "Base name for SG"
    type        = string
}
 
variable "container_port" {
    description = "Port to expose in SG"
    type        = number
}

variable "cidr_blocks" {
    description = "Which CIDRs can reach the service"
    type = list(string)
    default = ["0.0.0.0/0"]
}

variable "alb_security_group_ids" {
  description = "List of ALB security group IDs to allow traffic from"
  type        = list(string)
  default     = []
}