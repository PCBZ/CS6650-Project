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

# Attach AWS managed policies for ECS task execution
resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Additional managed policy for ECR access (CloudWatch already covered by AmazonECSTaskExecutionRolePolicy)
resource "aws_iam_role_policy_attachment" "ecs_task_execution_ecr_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
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

# Social Graph Service DynamoDB access - using managed policy
# Note: For more granular permissions, you would need an IAM admin to create a custom policy
resource "aws_iam_role_policy_attachment" "social_graph_dynamodb_full_access" {
  role       = aws_iam_role.social_graph_task_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess"
}
