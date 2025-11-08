# ECS Cluster
resource "aws_ecs_cluster" "this" {
    name = "${var.service_name}-cluster"
    // set monitoring enabled
    setting {
        name  = "containerInsights"
        value = "enabled"
    }
}

# Task Definition
resource "aws_ecs_task_definition" "this" {
    family                   = "${var.service_name}-task"
    network_mode             = "awsvpc"
    requires_compatibilities = ["FARGATE"]
    cpu                      = var.cpu
    memory                   = var.memory 

    execution_role_arn = var.execution_role_arn
    task_role_arn      = var.task_role_arn

    container_definitions = jsonencode([{
        name      = "${var.service_name}-container"
        image     = var.image
        essential = true

        portMappings = var.container_port != null ? [{
            containerPort = var.container_port
        }] : []

        environment = var.environment_variables

        logConfiguration = {
        logDriver = "awslogs"
        options = {
            "awslogs-group"         = var.log_group_name
            "awslogs-region"        = var.region
            "awslogs-stream-prefix" = "ecs"
        }
    }
    }])
}

# ECS
resource "aws_ecs_service" "this" {
    name = var.service_name
    cluster         = aws_ecs_cluster.this.id
    task_definition = aws_ecs_task_definition.this.arn
    desired_count   = var.ecs_count
    launch_type     = "FARGATE"   

    network_configuration {
    subnets         = var.subnet_ids
    security_groups = var.security_group_ids
    assign_public_ip = true # change to false when using ALB
  }

   # Only add load balancer if target_group_arn is provided
    dynamic "load_balancer" {
        for_each = var.target_group_arn != null ? [1] : []
        content {
            target_group_arn = var.target_group_arn
            container_name   = "${var.service_name}-container"
            container_port   = var.container_port
        }
    }
}

# Auto Scaling Target
resource "aws_appautoscaling_target" "ecs_target" {
  max_capacity       = var.max_capacity
  min_capacity       = var.min_capacity
  resource_id        = "service/${aws_ecs_cluster.this.name}/${aws_ecs_service.this.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"

  depends_on = [aws_ecs_service.this]
}

# Auto Scaling Policy - CPU Based 
resource "aws_appautoscaling_policy" "ecs_policy_cpu" {
  count              = var.scaling_metric == "cpu" ? 1 : 0
  name               = "${var.service_name}-cpu-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs_target.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_target.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs_target.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value       = var.target_cpu_utilization
    scale_out_cooldown = var.scale_out_cooldown
    scale_in_cooldown  = var.scale_in_cooldown
  }
}

# Auto Scaling Policy - SQS Based (for processors)
resource "aws_appautoscaling_policy" "ecs_policy_sqs" {
  count              = var.scaling_metric == "sqs" ? 1 : 0
  name               = "${var.service_name}-sqs-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs_target.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_target.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs_target.service_namespace

  target_tracking_scaling_policy_configuration {
    customized_metric_specification {
      metric_name = "ApproximateNumberOfVisibleMessages"
      namespace   = "AWS/SQS"
      statistic   = "Average"
      dimensions {
        name  = "QueueName"
        value = var.sqs_queue_name
      }
    }
    target_value       = var.sqs_target_value  # Scale when queue has more than X messages
    scale_out_cooldown = var.scale_out_cooldown
    scale_in_cooldown  = var.scale_in_cooldown
  }
}