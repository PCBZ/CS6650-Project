# Wire together modules: ecr, logging, ecs, DynamoDB

module "ecr" {
  source          = "./modules/ecr"
  repository_name = var.ecr_repository_name
}

module "logging" {
  source            = "./modules/logging"
  service_name      = var.service_name
  retention_in_days = var.log_retention_days
}

# Get current AWS caller identity to build IAM role ARN dynamically
data "aws_caller_identity" "current" {}

locals {
  # Build LabRole ARN dynamically using current AWS account ID
  lab_role_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/LabRole"
}

# Service-specific security group for ECS tasks
resource "aws_security_group" "app" {
  name_prefix = "${var.service_name}-app-"
  vpc_id      = var.vpc_id

  # Allow inbound traffic from ALB
  ingress {
    from_port   = var.container_port
    to_port     = var.container_port
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
    description = "Allow traffic from ALB and VPC"
  }

  # Allow gRPC traffic on port 50052 for inter-service communication
  ingress {
    from_port   = 50052
    to_port     = 50052
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
    description = "Allow gRPC traffic"
  }

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = {
    Name    = "${var.service_name} Application Security Group"
    Service = var.service_name
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Target group for this service in the shared ALB
resource "aws_lb_target_group" "service" {
  name        = "${replace(var.service_name, "_", "-")}-tg"
  port        = var.container_port
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = var.vpc_id

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    matcher             = "200"
    path                = "/health"
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
    unhealthy_threshold = 2
  }

  tags = {
    Name    = "${var.service_name} Target Group"
    Service = var.service_name
  }

  lifecycle {
    create_before_destroy = true
  }
}

# ALB listener rule for routing to this service
resource "aws_lb_listener_rule" "service" {
  listener_arn = var.alb_listener_arn
  priority     = var.alb_priority

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.service.arn
  }

  condition {
    path_pattern {
      values = ["/api/social-graph*"]
    }
  }

  tags = {
    Name    = "${var.service_name} ALB Rule"
    Service = var.service_name
  }
}

# Build & push image to ECR (local-exec)
resource "null_resource" "docker_build_push" {
  triggers = {
    dockerfile_hash = filesha256("${path.module}/../Dockerfile")
    handlers_hash   = filesha256("${path.module}/../src/handlers.go")
    ecr_repo        = module.ecr.repository_url
  }

  provisioner "local-exec" {
    command = var.is_windows ? join("; ", [
      "aws ecr get-login-password --region ${var.aws_region} | docker login --username AWS --password-stdin ${split("/", module.ecr.repository_url)[0]}",
      "if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }",
      "docker build -f services/social-graph-services/Dockerfile -t ${module.ecr.repository_url}:latest .",
      "if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }",
      "docker push ${module.ecr.repository_url}:latest"
    ]) : "aws ecr get-login-password --region ${var.aws_region} | docker login --username AWS --password-stdin ${split("/", module.ecr.repository_url)[0]} && docker build -f services/social-graph-services/Dockerfile -t ${module.ecr.repository_url}:latest . && docker push ${module.ecr.repository_url}:latest"
    interpreter = var.is_windows ? ["PowerShell", "-Command"] : ["bash", "-c"]
    working_dir = "${path.module}/../../.."
  }

  depends_on = [module.ecr]
}

# ECS module wiring
module "ecs" {
  source             = "./modules/ecs"
  service_name       = var.service_name
  image              = "${module.ecr.repository_url}:latest"
  container_port     = var.container_port
  subnet_ids         = var.public_subnet_ids
  security_group_ids = [aws_security_group.app.id]
  execution_role_arn = local.lab_role_arn
  task_role_arn      = local.lab_role_arn
  log_group_name     = module.logging.log_group_name
  target_group_arn   = aws_lb_target_group.service.arn
  ecs_count          = var.ecs_desired_count
  region             = var.aws_region
  service_connect_namespace_arn = var.service_connect_namespace_arn

  # Timeline service specific variables (using defaults/empty values for social-graph)
  dynamodb_table_name        = var.followers_table_name
  sqs_queue_url              = ""
  post_service_url           = ""
  social_graph_service_url   = ""
  user_service_url           = ""

  min_capacity                 = var.min_capacity
  max_capacity                 = var.max_capacity
  cpu_target_value            = var.cpu_target_value
  memory_target_value         = var.memory_target_value
  enable_request_based_scaling = var.enable_request_based_scaling
  request_count_target_value  = var.request_count_target_value
  alb_resource_label          = "${var.alb_arn_suffix}/${aws_lb_target_group.service.arn_suffix}"

  depends_on = [null_resource.docker_build_push]
}
