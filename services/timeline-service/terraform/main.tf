# Wire together modules: ecr, logging, ecs, DynamoDB, SQS

module "ecr" {
  source          = "./modules/ecr"
  repository_name = var.ecr_repository_name
}

module "logging" {
  source            = "./modules/logging"
  service_name      = var.service_name
  retention_in_days = var.log_retention_days
}

# SQS module for subscribing to post-service SNS notifications
module "sqs" {
  source = "./modules/sqs"
  
  service_name    = var.service_name
  environment     = "dev"
  sns_topic_arn   = var.post_service_sns_topic_arn
}

# Use IAM role ARN directly instead of data source (AWS learner lab permission issue)
locals {
  # Directly specify LabRole ARN for AWS learner lab environment
  lab_role_arn = "arn:aws:iam::964932215897:role/LabRole"
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
    create_before_destroy = false
  }
}

# Allow ECS service to access DynamoDB
resource "aws_security_group_rule" "app_to_dynamodb" {
  type              = "egress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.app.id
  description       = "Allow ${var.service_name} to access DynamoDB"
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
resource "aws_lb_listener_rule" "service" {
  listener_arn = var.alb_listener_arn
  priority     = var.alb_priority

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.service.arn
  }

  condition {
    path_pattern {
      values = ["/api/timeline*", "/timeline*"]
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
  # Use image digest to ensure ECS always pulls the latest image
  image              = "${module.ecr.repository_url}@${docker_registry_image.app.sha256_digest}"
  container_port     = var.container_port
  subnet_ids         = var.public_subnet_ids
  security_group_ids = [aws_security_group.app.id]
  execution_role_arn = var.execution_role_arn  # Innovation Sandbox with ISBStudent=true tag
  task_role_arn      = var.task_role_arn  # Task role for DynamoDB/SQS access
  log_group_name     = module.logging.log_group_name
  target_group_arn   = aws_lb_target_group.service.arn
  ecs_count          = var.ecs_count
  region             = var.aws_region
  service_connect_namespace_arn = var.service_connect_namespace_arn
  
  # Timeline Service specific configuration
  dynamodb_table_name       = aws_dynamodb_table.posts.name
  sqs_queue_url             = module.sqs.queue_url
  post_service_url          = var.post_service_url
  social_graph_service_url  = var.social_graph_service_url
  user_service_url          = var.user_service_url
  fanout_strategy           = var.fanout_strategy
  celebrity_threshold       = var.celebrity_threshold

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
    context    = "${path.module}/../../.."  # Project root (Dockerfile expects proto/)
    dockerfile = "services/timeline-service/Dockerfile"  # Path to Dockerfile from project root
    pull_parent = false
    no_cache    = false
    remove      = true
  }

  # Force rebuild on trigger changes
  triggers = {
    dockerfile_hash = filemd5("${path.module}/../Dockerfile")
    src_hash       = sha1(join("", [for f in fileset("${path.module}/../src", "**/*.go") : filemd5("${path.module}/../src/${f}")]))
    proto_hash     = sha1(join("", [for f in fileset("${path.module}/../proto", "**/*.proto") : filemd5("${path.module}/../proto/${f}")]))
  }
}

resource "docker_registry_image" "app" {
  name          = docker_image.app.name
  
  # Ensure the image is built before pushing
  depends_on = [docker_image.app]
}
