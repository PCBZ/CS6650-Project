output "table_name" {
  description = "Name of the DynamoDB posts table"
  value       = aws_dynamodb_table.posts.name
}

output "table_arn" {
  description = "ARN of the DynamoDB posts table"
  value       = aws_dynamodb_table.posts.arn
}
