terraform {
  required_version = ">= 1.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Data sources to get shared infrastructure
data "terraform_remote_state" "shared_infra" {
  backend = "local"
  
  config = {
    path = "../../terraform/terraform.tfstate"
  }
}

# Get AWS account ID
data "aws_caller_identity" "current" {}

# ECR Repository
module "ecr" {
  source = "./modules/ecr"
  
  repository_name = "grpc-test-client"
}

# CloudWatch Logs
module "logging" {
  source = "./modules/logging"
  
  service_name      = "grpc-test-client"
  retention_in_days = 7
}

# IAM Role for ECS Task Execution
resource "aws_iam_role" "ecs_execution_role" {
  name = "grpc-test-client-execution-role"

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
}

resource "aws_iam_role_policy_attachment" "ecs_execution_role_policy" {
  role       = aws_iam_role.ecs_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# IAM Role for ECS Task
resource "aws_iam_role" "ecs_task_role" {
  name = "grpc-test-client-task-role"

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
}

# Build and push Docker image using null_resource
resource "null_resource" "docker_build_push" {
  triggers = {
    # Rebuild when these files change
    dockerfile_hash = filemd5("${path.module}/../Dockerfile")
    main_go_hash    = filemd5("${path.module}/../main.go")
    ecr_url         = module.ecr.repository_url
  }

  provisioner "local-exec" {
    working_dir = "${path.module}/.."
    command     = <<-EOT
      # Login to ECR
      aws ecr get-login-password --region ${var.aws_region} | docker login --username AWS --password-stdin ${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com
      
      # Build image
      docker build -t grpc-test-client:latest .
      
      # Tag image
      docker tag grpc-test-client:latest ${module.ecr.repository_url}:latest
      
      # Push image
      docker push ${module.ecr.repository_url}:latest
    EOT
  }

  depends_on = [module.ecr]
}

# ECS Module
module "ecs" {
  source = "./modules/ecs"
  
  service_name                  = "grpc-test-client"
  image                         = "${module.ecr.repository_url}:latest"
  cpu                           = "256"
  memory                        = "512"
  execution_role_arn            = aws_iam_role.ecs_execution_role.arn
  task_role_arn                 = aws_iam_role.ecs_task_role.arn
  log_group_name                = module.logging.log_group_name
  region                        = var.aws_region
  vpc_id                        = data.terraform_remote_state.shared_infra.outputs.vpc_id
  grpc_server_address           = "user-service-grpc:50051"
  service_connect_namespace_arn = data.terraform_remote_state.shared_infra.outputs.service_connect_namespace_arn

  depends_on = [null_resource.docker_build_push]
}
