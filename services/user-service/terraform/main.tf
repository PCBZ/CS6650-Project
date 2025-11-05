# Wire together four focused modules: network, ecr, logging, ecs.

# Reference shared infrastructure from root terraform
data "terraform_remote_state" "shared" {
  backend = "local"

  config = {
    path = "../../../terraform/terraform.tfstate"
  }
}

module "ecr" {
  source          = "./modules/ecr"
  repository_name = var.ecr_repository_name
}

module "logging" {
  source            = "./modules/logging"
  service_name      = var.service_name
  retention_in_days = var.log_retention_days
}

# Reuse an existing IAM role for ECS tasks
data "aws_iam_role" "lab_role" {
  name = "LabRole"
}

# Service-specific security group for ECS tasks
module "app_security_group" {
  source = "./modules/security_group"
  
  service_name = var.service_name
  vpc_id       = data.terraform_remote_state.shared.outputs.vpc_id
  vpc_cidr     = data.terraform_remote_state.shared.outputs.vpc_cidr
}

# Allow ECS service to access RDS
resource "aws_security_group_rule" "app_to_rds" {
  type                     = "ingress"
  from_port                = data.terraform_remote_state.shared.outputs.rds_port
  to_port                  = data.terraform_remote_state.shared.outputs.rds_port
  protocol                 = "tcp"
  source_security_group_id = module.app_security_group.security_group_id
  security_group_id        = data.terraform_remote_state.shared.outputs.rds_security_group_id
  description              = "Allow ${var.service_name} to access RDS"
}

# Target group for this service in the shared ALB
resource "aws_lb_target_group" "service" {
  name        = "${replace(var.service_name, "_", "-")}-tg"
  port        = var.container_port
  protocol    = "HTTP"
  target_type = "ip"  # Required for ECS Fargate
  vpc_id      = data.terraform_remote_state.shared.outputs.vpc_id

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
  listener_arn = data.terraform_remote_state.shared.outputs.alb_listener_arn
  priority     = var.alb_priority

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.service.arn
  }

  condition {
    path_pattern {
      values = ["/api/users*"]
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
  subnet_ids         = data.terraform_remote_state.shared.outputs.private_subnet_ids
  security_group_ids = [module.app_security_group.security_group_id]
  execution_role_arn = data.aws_iam_role.lab_role.arn
  task_role_arn      = data.aws_iam_role.lab_role.arn
  log_group_name     = module.logging.log_group_name
  target_group_arn   = aws_lb_target_group.service.arn
  ecs_count          = var.ecs_count
  region             = var.aws_region
  
  # Database connection environment variables (shared RDS)
  db_host     = data.terraform_remote_state.shared.outputs.rds_address
  db_port     = data.terraform_remote_state.shared.outputs.rds_port
  db_name     = var.database_name
  db_password = var.rds_master_password

  # Auto-scaling configuration
  min_capacity                 = var.min_capacity
  max_capacity                = var.max_capacity
  cpu_target_value            = var.cpu_target_value
  memory_target_value         = var.memory_target_value
  enable_request_based_scaling = var.enable_request_based_scaling
  request_count_target_value  = var.request_count_target_value
}

# Build & push the Go app image into ECR
resource "docker_image" "app" {
  name = "${module.ecr.repository_url}:latest"

  build {
    context = ".."
  }
}

resource "docker_registry_image" "app" {
  name = docker_image.app.name
}
