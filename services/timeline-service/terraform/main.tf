# Wire together three focused modules: ecr, logging, ecs, and dynamodb.

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
locals {
  # Directly specify LabRole ARN for AWS learner lab environment
  lab_role_arn = "arn:aws:iam::291524115576:role/LabRole"
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

  # Allow all outbound traffic (needed for DynamoDB, SQS, and other service communication)
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
      values = ["/api/timeline*"]
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
  image              = "${module.ecr.repository_url}:latest"
  container_port     = var.container_port
  subnet_ids         = var.public_subnet_ids
  security_group_ids = [aws_security_group.app.id]
  execution_role_arn = local.lab_role_arn
  task_role_arn      = local.lab_role_arn
  log_group_name     = module.logging.log_group_name
  target_group_arn   = aws_lb_target_group.service.arn
  ecs_count          = var.ecs_count
  region             = var.aws_region
  service_connect_namespace_arn = var.service_connect_namespace_arn
  
  # Timeline service specific environment variables
  dynamodb_table_name       = var.dynamodb_table_name
  sqs_queue_url             = var.sqs_queue_url
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

  depends_on = [null_resource.docker_build_push]
}

# Build & push the Go app image into ECR using local-exec
# This approach respects .dockerignore and is faster than docker provider
resource "null_resource" "docker_build_push" {
  triggers = {
    # Rebuild if source files or Dockerfile changes
    dockerfile_hash = filesha256("${path.module}/../Dockerfile")
    main_go_hash    = filesha256("${path.module}/../src/main.go")
    ecr_repo        = module.ecr.repository_url
  }

  provisioner "local-exec" {
    command     = <<-EOT
      export DOCKER_CONFIG=$(mktemp -d) && \
      echo '{"credsStore":""}' > $DOCKER_CONFIG/config.json && \
      aws ecr get-login-password --region ${var.aws_region} | docker login --username AWS --password-stdin ${split("/", module.ecr.repository_url)[0]} && \
      docker build -f services/timeline-service/Dockerfile -t ${module.ecr.repository_url}:latest . && \
      docker push ${module.ecr.repository_url}:latest && \
      rm -rf $DOCKER_CONFIG
    EOT
    working_dir = "${path.module}/../../.."
  }

  depends_on = [module.ecr]
}
