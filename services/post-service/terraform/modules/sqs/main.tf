resource "aws_sqs_queue" "order_queue" {
    name                      = "${var.service_name}-order-queue"
    delay_seconds             = var.delay_seconds
    max_message_size          = var.max_message_size
    message_retention_seconds = var.message_retention_seconds
    receive_wait_time_seconds = var.receive_wait_time_seconds
    visibility_timeout_seconds = var.visibility_timeout_seconds

    tags = {
      Name        = "${var.service_name}-order-queue"
      Environment = var.environment
    } 
}

resource "aws_sqs_queue_policy" "order_queue_policy" {
    queue_url = aws_sqs_queue.order_queue.id

    policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
          {
            Effect = "Allow"
            Principal = {
            Service = "sns.amazonaws.com"
            }
            Action   = "sqs:SendMessage"
            Resource = aws_sqs_queue.order_queue.arn
            Condition = {
                ArnEquals = {
                    "aws:SourceArn" = var.sns_topic_arn
                }
            }
          }
        ]
    })
}