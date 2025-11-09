# ECS Cluster (Service Connect configured at service level)
resource "aws_ecs_cluster" "main" {
  name = var.service_name

  tags = {
    Name    = "${var.service_name} Cluster"
    Service = var.service_name
  }
}

# Task Definition
resource "aws_ecs_task_definition" "app" {
  family                   = var.service_name
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.cpu
  memory                   = var.memory
  execution_role_arn       = var.execution_role_arn  # Innovation Sandbox with ISBStudent=true tag
  task_role_arn            = var.task_role_arn != "" ? var.task_role_arn : var.execution_role_arn  # Use task_role if provided

  # Specify CPU architecture for Fargate
  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }

  container_definitions = jsonencode([
    {
      name  = var.service_name
      image = var.image
      
      portMappings = [
        {
          name          = "http"
          containerPort = var.container_port
          hostPort      = var.container_port
          protocol      = "tcp"
          appProtocol   = "http"
        },
        {
          name          = "grpc"
          containerPort = 50052
          hostPort      = 50052
          protocol      = "tcp"
          appProtocol   = "grpc"
        }
      ]

      environment = [
        {
          name  = "PORT"
          value = tostring(var.container_port)
        },
        {
          name  = "AWS_REGION"
          value = var.region
        },
        {
          name  = "DYNAMODB_TABLE_NAME"
          value = var.dynamodb_table_name
        },
        {
          name  = "SQS_QUEUE_URL"
          value = var.sqs_queue_url
        },
        {
          name  = "POST_SERVICE_URL"
          value = var.post_service_url
        },
        {
          name  = "SOCIAL_GRAPH_SERVICE_URL"
          value = var.social_graph_service_url
        },
        {
          name  = "USER_SERVICE_URL"
          value = var.user_service_url
        },
        {
          name  = "FANOUT_STRATEGY"
          value = var.fanout_strategy
        },
        {
          name  = "CELEBRITY_THRESHOLD"
          value = tostring(var.celebrity_threshold)
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = var.log_group_name
          "awslogs-region"        = var.region
          "awslogs-stream-prefix" = "ecs"
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

# ECS Service with Service Connect
resource "aws_ecs_service" "app" {
  name            = var.service_name
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.app.arn
  desired_count   = var.ecs_count
  launch_type     = "FARGATE"

  # CRITICAL: Ensure clean shutdown during destroy
  enable_execute_command = false
  wait_for_steady_state  = false

  network_configuration {
    subnets          = var.subnet_ids
    security_groups  = var.security_group_ids
    assign_public_ip = true  # Changed from false - allows direct internet access via IGW
  }

  load_balancer {
    target_group_arn = var.target_group_arn
    container_name   = var.service_name
    container_port   = var.container_port
  }

  # ECS Service Connect configuration
  service_connect_configuration {
    enabled   = true
    namespace = var.service_connect_namespace_arn

    service {
      port_name      = "http"
      discovery_name = var.service_name
      
      client_alias {
        port     = var.container_port
        dns_name = var.service_name
      }
    }

    service {
      port_name      = "grpc"
      discovery_name = "${var.service_name}-grpc"
      
      client_alias {
        port     = 50052
        dns_name = "${var.service_name}-grpc"
      }
    }
  }

  depends_on = [var.target_group_arn]

  tags = {
    Name    = "${var.service_name} Service"
    Service = var.service_name
  }

  lifecycle {
    ignore_changes = [desired_count] # Let auto-scaling manage this
  }
}

# Auto Scaling Target
resource "aws_appautoscaling_target" "ecs_target" {
  max_capacity       = var.max_capacity
  min_capacity       = var.min_capacity
  resource_id        = "service/${aws_ecs_cluster.main.name}/${aws_ecs_service.app.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"

  tags = {
    Name    = "${var.service_name} Auto Scaling Target"
    Service = var.service_name
  }
}

# Scale Up Policy (CPU-based)
resource "aws_appautoscaling_policy" "scale_up_cpu" {
  name               = "${var.service_name}-scale-up-cpu"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs_target.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_target.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs_target.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value       = var.cpu_target_value
    scale_in_cooldown  = var.scale_in_cooldown
    scale_out_cooldown = var.scale_out_cooldown
  }
}

# Scale Up Policy (Memory-based)
resource "aws_appautoscaling_policy" "scale_up_memory" {
  name               = "${var.service_name}-scale-up-memory"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs_target.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_target.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs_target.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageMemoryUtilization"
    }
    target_value       = var.memory_target_value
    scale_in_cooldown  = var.scale_in_cooldown
    scale_out_cooldown = var.scale_out_cooldown
  }
}

# Scale Up Policy (ALB Request Count based)
resource "aws_appautoscaling_policy" "scale_up_requests" {
  count              = var.enable_request_based_scaling ? 1 : 0
  name               = "${var.service_name}-scale-up-requests"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs_target.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_target.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs_target.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ALBRequestCountPerTarget"
      resource_label         = var.alb_resource_label
    }
    target_value       = var.request_count_target_value
    scale_in_cooldown  = var.scale_in_cooldown
    scale_out_cooldown = var.scale_out_cooldown
  }
}

# CloudWatch Alarms for monitoring
resource "aws_cloudwatch_metric_alarm" "high_cpu" {
  alarm_name          = "${var.service_name}-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "This metric monitors ECS CPU utilization"
  alarm_actions       = var.alarm_actions

  dimensions = {
    ServiceName = aws_ecs_service.app.name
    ClusterName = aws_ecs_cluster.main.name
  }

  tags = {
    Name    = "${var.service_name} High CPU Alarm"
    Service = var.service_name
  }
}

resource "aws_cloudwatch_metric_alarm" "high_memory" {
  alarm_name          = "${var.service_name}-high-memory"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "MemoryUtilization"
  namespace           = "AWS/ECS"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "This metric monitors ECS memory utilization"
  alarm_actions       = var.alarm_actions

  dimensions = {
    ServiceName = aws_ecs_service.app.name
    ClusterName = aws_ecs_cluster.main.name
  }

  tags = {
    Name    = "${var.service_name} High Memory Alarm"
    Service = var.service_name
  }
}
