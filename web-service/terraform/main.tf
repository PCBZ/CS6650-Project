# Wire together three focused modules: ecr, logging, ecs.

module "ecr" {
  source          = "./modules/ecr"
  repository_name = var.ecr_repository_name
}

module "logging" {
  source            = "./modules/logging"
  service_name      = var.service_name
  retention_in_days = var.log_retention_days
}

# Use IAM role ARN directly instead of data source (AWS learner lab permission issue)
# data "aws_iam_role" "lab_role" {
#   name = "LabRole"
# }

locals {
  # Directly specify LabRole ARN for AWS learner lab environment
  lab_role_arn = "arn:aws:iam::964932215897:role/LabRole"
}

# Service-specific security group for ECS tasks
resource "aws_security_group" "app" {
  name_prefix = "${var.service_name}-app-"
  vpc_id      = var.vpc_id

  # Allow inbound traffic from ALB on the container port
  ingress {
    from_port   = var.container_port
    to_port     = var.container_port
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
    description = "Allow traffic from ALB"
  }

  # Allow all outbound traffic (needed to communicate with user-service and internet)
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

  # CRITICAL: Ensure this security group is destroyed before VPC
  lifecycle {
    create_before_destroy = false
  }
}

# Allow web-service to communicate with user-service on gRPC port
resource "aws_security_group_rule" "web_to_user_grpc" {
  type                     = "ingress"
  from_port                = 50051
  to_port                  = 50051
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.app.id
  security_group_id        = var.user_service_security_group_id
  description              = "Allow web-service to call user-service gRPC"
}

# Target group for this service in the shared ALB
resource "aws_lb_target_group" "service" {
  name        = "${replace(var.service_name, "_", "-")}-tg"
  port        = var.container_port
  protocol    = "HTTP"
  target_type = "ip"  # Required for ECS Fargate
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
# Web-service gets ALL traffic (catch-all), so it should have lower priority
resource "aws_lb_listener_rule" "service" {
  listener_arn = var.alb_listener_arn
  priority     = var.alb_priority

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.service.arn
  }

  condition {
    path_pattern {
      values = ["/*"]
    }
  }

  tags = {
    Name    = "${var.service_name} ALB Rule"
    Service = var.service_name
  }
}

module "ecs" {
  source             = "./modules/ecs"
  service_name       = var.service_name
  # NOTE: AWS Innovation Sandbox limitations prevent using private ECR
  # - Cannot create IAM execution roles (iam:CreateRole denied by SCP)
  # - Fargate requires execution role to pull from private ECR
  # Docker image successfully built and pushed to: ${module.ecr.repository_url}:latest
  # To use it, add execution_role_arn to task definition when you have IAM permissions
  image              = "public.ecr.aws/nginx/nginx:latest"
  container_port     = var.container_port
  subnet_ids         = var.public_subnet_ids
  security_group_ids = [aws_security_group.app.id]
  # execution_role_arn and task_role_arn removed - not supported in AWS Innovation Sandbox
  log_group_name     = module.logging.log_group_name
  target_group_arn   = aws_lb_target_group.service.arn
  ecs_count          = var.ecs_count
  region             = var.aws_region
  service_connect_namespace_arn = var.service_connect_namespace_arn
  
  # Web service needs to know where user-service is
  user_service_url       = var.user_service_url
  user_service_grpc_host = var.user_service_grpc_host
  
  # Web service needs to know where timeline-service is
  timeline_service_url   = var.timeline_service_url

  # Auto-scaling configuration
  min_capacity                 = var.min_capacity
  max_capacity                = var.max_capacity
  cpu_target_value            = var.cpu_target_value
  memory_target_value         = var.memory_target_value
  enable_request_based_scaling = var.enable_request_based_scaling
  request_count_target_value  = var.request_count_target_value
  alb_resource_label          = "${var.alb_arn_suffix}/${aws_lb_target_group.service.arn_suffix}"
  
  # Ensure ECS service waits for Docker image to be pushed
  depends_on = [docker_registry_image.app]
}

# Build & push the Go app image into ECR
resource "docker_image" "app" {
  name = "${module.ecr.repository_url}:latest"

  build {
    context    = "/Users/wenshuangzhou/Developer/CS6650-Project"  # Project root (Dockerfile expects proto/)
    dockerfile = "web-service/Dockerfile"  # Path to Dockerfile from project root
    pull_parent = false
    no_cache    = false
    remove      = true
  }

  # Force rebuild on trigger changes
  triggers = {
    dockerfile_hash = filemd5("${path.module}/../Dockerfile")
    src_hash       = sha1(join("", [for f in fileset("${path.module}/../", "**/*.go") : filemd5("${path.module}/../${f}")]))
  }
}

resource "docker_registry_image" "app" {
  name          = docker_image.app.name
  keep_remotely = true  # Don't delete from ECR when destroyed
  
  # Ensure the image is built before pushing
  depends_on = [docker_image.app]
}
