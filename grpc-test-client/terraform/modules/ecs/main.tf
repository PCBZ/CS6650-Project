# ECS Cluster
resource "aws_ecs_cluster" "main" {
  name = var.service_name

  service_connect_defaults {
    namespace = var.service_connect_namespace_arn
  }

  tags = {
    Name    = "${var.service_name} Cluster"
    Service = var.service_name
  }
}

# Task Definition for gRPC Test Client
resource "aws_ecs_task_definition" "test_client" {
  family                   = var.service_name
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.cpu
  memory                   = var.memory
  execution_role_arn       = var.execution_role_arn
  task_role_arn            = var.task_role_arn

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }

  container_definitions = jsonencode([
    {
      name  = var.service_name
      image = var.image

      # No port mappings needed - this is a client, not a server
      
      environment = [
        {
          name  = "GRPC_SERVER"
          value = var.grpc_server_address
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = var.log_group_name
          awslogs-region        = var.region
          awslogs-stream-prefix = "ecs"
        }
      }

      essential = true
    }
  ])

  tags = {
    Name    = "${var.service_name} Task Definition"
    Service = var.service_name
  }
}

# Security Group for gRPC Test Client
resource "aws_security_group" "test_client" {
  name_prefix = "${var.service_name}-"
  vpc_id      = var.vpc_id
  description = "Security group for gRPC test client"

  # Allow all outbound traffic (needed to connect to user-service)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "${var.service_name} Security Group"
    Service = var.service_name
  }

  lifecycle {
    create_before_destroy = true
  }
}
