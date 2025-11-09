# ECS Task Execution Role (used by all services)
# This role is used by ECS to pull images and write logs
resource "aws_iam_role" "ecs_task_execution_role" {
  name = "${var.project_name}-${var.environment}-ecs-execution-role"

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
    Name        = "${var.project_name}-${var.environment}-ecs-execution-role"
    Project     = var.project_name
    Environment = var.environment
    ISBStudent  = "true"
  }
}

# Attach AWS managed policy for ECS task execution
resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Additional policy for ECR access
resource "aws_iam_role_policy" "ecs_task_execution_ecr_policy" {
  name = "${var.project_name}-${var.environment}-ecs-execution-ecr-policy"
  role = aws_iam_role.ecs_task_execution_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:${var.aws_region}:${var.aws_account_id}:log-group:/ecs/*"
      }
    ]
  })
}

# Social Graph Service Task Role (for DynamoDB access)
resource "aws_iam_role" "social_graph_task_role" {
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
    Project     = var.project_name
    Environment = var.environment
    ISBStudent  = "true"
  }
}

# Social Graph Service DynamoDB access policy
resource "aws_iam_role_policy" "social_graph_task_policy" {
  name = "${var.project_name}-${var.environment}-social-graph-task-policy"
  role = aws_iam_role.social_graph_task_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:PutItem",
          "dynamodb:GetItem",
          "dynamodb:Query",
          "dynamodb:Scan",
          "dynamodb:UpdateItem",
          "dynamodb:DeleteItem",
          "dynamodb:BatchGetItem",
          "dynamodb:BatchWriteItem"
        ]
        Resource = [
          "arn:aws:dynamodb:${var.aws_region}:${var.aws_account_id}:table/social-graph-followers",
          "arn:aws:dynamodb:${var.aws_region}:${var.aws_account_id}:table/social-graph-followers/*",
          "arn:aws:dynamodb:${var.aws_region}:${var.aws_account_id}:table/social-graph-following",
          "arn:aws:dynamodb:${var.aws_region}:${var.aws_account_id}:table/social-graph-following/*"
        ]
      }
    ]
  })
}
