output "log_group_name" {
    description = "name of the CloudWath log group"
    value       = aws_cloudwatch_log_group.this.name
}