output "queue_url" {
  description = "URL of the SQS queue (for SDK operations)"
  value       = aws_sqs_queue.timeline_queue.id
}

output "queue_arn" {
  description = "ARN of the SQS queue"
  value       = aws_sqs_queue.timeline_queue.arn
}

output "queue_name" {
  description = "Name of the SQS queue"
  value       = aws_sqs_queue.timeline_queue.name
}
