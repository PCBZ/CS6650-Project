# ECS Task Execution Role
resource "aws_iam_role" "ecs_task_execution_role" {
  name = "${var.project_name}-${var.environment}-ecs-task-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-${var.environment}-ecs-task-execution-role"
    Environment = var.environment
    ISBStudent  = "true"  # Required for Innovation Sandbox IAM role creation
  }
}

# Attach AWS managed policy for ECS task execution
resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Post Service Task Role (for DynamoDB and SNS access)
resource "aws_iam_role" "post_service_task_role" {
  name = "${var.project_name}-${var.environment}-post-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-${var.environment}-post-task-role"
    Environment = var.environment
    ISBStudent  = "true"  # Required for Innovation Sandbox IAM role creation
  }
}

# Attach AWS managed policies for DynamoDB and SNS
resource "aws_iam_role_policy_attachment" "post_dynamodb" {
  role       = aws_iam_role.post_service_task_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess"
}

resource "aws_iam_role_policy_attachment" "post_sns" {
  role       = aws_iam_role.post_service_task_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSNSFullAccess"
}

# Timeline Service Task Role (for DynamoDB and SQS access)
resource "aws_iam_role" "timeline_service_task_role" {
  name = "${var.project_name}-${var.environment}-timeline-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-${var.environment}-timeline-task-role"
    Environment = var.environment
    ISBStudent  = "true"  # Required for Innovation Sandbox IAM role creation
  }
}

resource "aws_iam_role_policy_attachment" "timeline_dynamodb" {
  role       = aws_iam_role.timeline_service_task_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess"
}

resource "aws_iam_role_policy_attachment" "timeline_sqs" {
  role       = aws_iam_role.timeline_service_task_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSQSFullAccess"
}

# Social Graph Service Task Role (for DynamoDB access)
resource "aws_iam_role" "social_graph_service_task_role" {
  name = "${var.project_name}-${var.environment}-social-graph-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-${var.environment}-social-graph-task-role"
    Environment = var.environment
    ISBStudent  = "true"  # Required for Innovation Sandbox IAM role creation
  }
}

resource "aws_iam_role_policy_attachment" "social_graph_dynamodb" {
  role       = aws_iam_role.social_graph_service_task_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess"
}
