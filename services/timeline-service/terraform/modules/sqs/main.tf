# SQS Queue for Timeline Service to consume post notifications
resource "aws_sqs_queue" "timeline_queue" {
  name                      = "${var.service_name}-${var.environment}-queue"
  delay_seconds             = 0
  max_message_size          = 262144  # 256 KB
  message_retention_seconds = 1209600 # 14 days
  receive_wait_time_seconds = 20      # Long polling
  visibility_timeout_seconds = 30

  tags = {
    Name        = "${var.service_name}-${var.environment}-queue"
    Environment = var.environment
    Service     = var.service_name
  }
}

# SQS Queue Policy to allow SNS to publish messages
resource "aws_sqs_queue_policy" "timeline_queue_policy" {
  queue_url = aws_sqs_queue.timeline_queue.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "sns.amazonaws.com"
        }
        Action   = "SQS:SendMessage"
        Resource = aws_sqs_queue.timeline_queue.arn
        Condition = {
          ArnEquals = {
            "aws:SourceArn" = var.sns_topic_arn
          }
        }
      }
    ]
  })
}

# Subscribe SQS queue to SNS topic
resource "aws_sns_topic_subscription" "timeline_subscription" {
  topic_arn = var.sns_topic_arn
  protocol  = "sqs"
  endpoint  = aws_sqs_queue.timeline_queue.arn

  # Enable raw message delivery to avoid SNS wrapper
  raw_message_delivery = true
}
