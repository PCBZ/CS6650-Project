output "topic_arn" {
  description = "ARN of the SNS topic"
  value       = aws_sns_topic.order_topic.arn
}

output "topic_name" {
  description = "Name of the SNS topic"
  value       = aws_sns_topic.order_topic.name
}