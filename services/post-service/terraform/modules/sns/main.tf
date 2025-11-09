resource  "aws_sns_topic" "order_topic" {
    name = "${var.service_name}-order-topic"

    tags = {
        Name        = "${var.service_name}-order-topic"
        Environment = var.environment
    }
}

resource "aws_sns_topic_subscription" "order_subscription" {
    topic_arn = aws_sns_topic.order_topic.arn
    protocol  = "sqs"
    endpoint   = var.sqs_queue_arn
}