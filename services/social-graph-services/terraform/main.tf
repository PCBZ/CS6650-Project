provider "aws" {
	region = var.aws_region
}

# ECR repository (re-use user-service module)
module "ecr" {
	source          = "../../user-service/terraform/modules/ecr"
	repository_name = var.ecr_repository_name
}

# CloudWatch logging (re-use user-service module)
module "logging" {
	source            = "../../user-service/terraform/modules/logging"
	service_name      = var.service_name
	retention_in_days = var.log_retention_days
}

# IAM roles for ECS (task and execution) with ISBStudent tag
resource "aws_iam_role" "ecs_task_role" {
	name = "${var.service_name}-task-role"

	assume_role_policy = jsonencode({
		Version = "2012-10-17"
		Statement = [
			{
				Action = "sts:AssumeRole"
				Effect = "Allow"
				Principal = { Service = "ecs-tasks.amazonaws.com" }
			}
		]
	})

	tags = merge({ Name = "${var.service_name}-task-role", ISBStudent = "true" }, var.common_tags)
}

resource "aws_iam_role" "ecs_execution_role" {
	name = "${var.service_name}-execution-role"

	assume_role_policy = jsonencode({
		Version = "2012-10-17"
		Statement = [
			{
				Action = "sts:AssumeRole"
				Effect = "Allow"
				Principal = { Service = "ecs-tasks.amazonaws.com" }
			}
		]
	})

	tags = merge({ Name = "${var.service_name}-execution-role", ISBStudent = "true" }, var.common_tags)
}

resource "aws_iam_policy_attachment" "exec_attach" {
	name       = "${var.service_name}-exec-policy-attach"
	roles      = [aws_iam_role.ecs_execution_role.name]
	policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Grant the task role basic DynamoDB access to the followers table
resource "aws_iam_policy" "dynamodb_access" {
	name        = "${var.service_name}-dynamodb-access"
	description = "Allow access to followers and following DynamoDB tables"

	policy = jsonencode({
		Version = "2012-10-17",
		Statement = [
			{
				Effect = "Allow",
				Action = [
					"dynamodb:PutItem",
					"dynamodb:GetItem",
					"dynamodb:Query",
					"dynamodb:Scan",
					"dynamodb:UpdateItem"
				],
				Resource = [
					aws_dynamodb_table.followers.arn,
					"${aws_dynamodb_table.followers.arn}/*",
					aws_dynamodb_table.following.arn,
					"${aws_dynamodb_table.following.arn}/*"
				]
			}
		]
	})
}

resource "aws_iam_policy_attachment" "task_dynamo_attach" {
	name       = "${var.service_name}-task-dynamo-attach"
	roles      = [aws_iam_role.ecs_task_role.name]
	policy_arn = aws_iam_policy.dynamodb_access.arn
}

# DynamoDB table for followers
resource "aws_dynamodb_table" "followers" {
	name         = var.dynamodb_table_name
	billing_mode = "PAY_PER_REQUEST"
	hash_key     = "user_id"

	attribute {
		name = "user_id"
		type = "S"
	}

	tags = merge({ Name = var.dynamodb_table_name, Service = var.service_name, ISBStudent = "true" }, var.common_tags)
}

	# DynamoDB table for following (mirror structure)
	resource "aws_dynamodb_table" "following" {
		name         = var.dynamodb_following_table_name
		billing_mode = "PAY_PER_REQUEST"
		hash_key     = "user_id"

		attribute {
			name = "user_id"
			type = "S"
		}

		tags = merge({ Name = var.dynamodb_following_table_name, Service = var.service_name, ISBStudent = "true" }, var.common_tags)
	}

# ECS security group (application)
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

	# Allow gRPC traffic on port 50051 (if needed for inter-service communication)
	ingress {
		from_port   = 50051
		to_port     = 50051
		protocol    = "tcp"
		cidr_blocks = [var.vpc_cidr]
		description = "Allow gRPC traffic"
	}

	# Allow all outbound
	egress {
		from_port   = 0
		to_port     = 0
		protocol    = "-1"
		cidr_blocks = ["0.0.0.0/0"]
		description = "Allow all outbound traffic"
	}

	tags = merge({ Name = "${var.service_name} Application Security Group", Service = var.service_name }, var.common_tags)

	lifecycle {
		create_before_destroy = false
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

	tags = merge({ Name = "${var.service_name} Target Group", Service = var.service_name }, var.common_tags)

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

	tags = merge({ Name = "${var.service_name} ALB Rule", Service = var.service_name }, var.common_tags)
}

# Build & push image to ECR (local-exec)
resource "null_resource" "docker_build_push" {
	triggers = {
		dockerfile_hash = filesha256("${path.module}/../Dockerfile")
		main_go_hash    = filesha256("${path.module}/../main.go")
		ecr_repo        = module.ecr.repository_url
	}

	provisioner "local-exec" {
		command     = <<-EOT
			export DOCKER_CONFIG=$(mktemp -d) && \
			echo '{"credsStore":""}' > $DOCKER_CONFIG/config.json && \
			aws ecr get-login-password --region ${var.aws_region} | docker login --username AWS --password-stdin ${split("/", module.ecr.repository_url)[0]} && \
			docker build -f services/social-graph-services/Dockerfile -t ${module.ecr.repository_url}:latest . && \
			docker push ${module.ecr.repository_url}:latest && \
			rm -rf $DOCKER_CONFIG
		EOT
		working_dir = "${path.module}/../../.."
	}

	depends_on = [module.ecr]
}

# ECS module wiring (re-use user-service ecs module)
module "ecs" {
	source             = "../../user-service/terraform/modules/ecs"
	service_name       = var.service_name
	image              = "${module.ecr.repository_url}:latest"
	container_port     = var.container_port
	subnet_ids         = var.public_subnet_ids
	security_group_ids = [aws_security_group.app.id]
	execution_role_arn = aws_iam_role.ecs_execution_role.arn
	task_role_arn      = aws_iam_role.ecs_task_role.arn
	log_group_name     = module.logging.log_group_name
	target_group_arn   = aws_lb_target_group.service.arn
	ecs_count          = var.ecs_desired_count
	region             = var.aws_region
	service_connect_namespace_arn = var.service_connect_namespace_arn

	# Database environment variables (optional - social-graph uses DynamoDB)
	db_host     = var.db_host
	db_port     = var.db_port
	db_name     = var.db_name
	db_password = var.db_password

	min_capacity                 = var.min_capacity
	max_capacity                 = var.max_capacity
	cpu_target_value            = var.cpu_target_value
	memory_target_value         = var.memory_target_value
	enable_request_based_scaling = var.enable_request_based_scaling
	request_count_target_value  = var.request_count_target_value
	alb_resource_label          = "${var.alb_arn_suffix}/${aws_lb_target_group.service.arn_suffix}"

	depends_on = [null_resource.docker_build_push]
}

