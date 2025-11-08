## configure port and security group
module "network"  {
    source         = "./modules/network"
    service_name   = var.service_name
    container_port = var.container_port
}

## configure ecr repository
module "ecr" {
    source           = "./modules/ecr"
    respository_name = var.repository_name
}


## configure logging
module "logging" {
    source            = "./modules/logging"
    service_name      = "${var.service_name}-receiver"
    retention_in_days = var.log_retention_days
}


## configure SQS queue
module "sqs" {
  source = "./modules/sqs"
  service_name = var.service_name
  environment = var.environment
  sns_topic_arn = module.sns.topic_arn
}

## configure SNS topic
module "sns" {
  source = "./modules/sns"
  service_name = var.service_name
  environment = var.environment
  sqs_queue_arn = module.sqs.queue_arn
}

## configure dynamodb tables
module "dynamodb" {
    source = "./modules/dynamodb"
}

## configure ecs
# Reuse an existing IAM role for ECS tasks
data "aws_iam_role" "lab_role" {
  name = "LabRole"
}

module "ecs" {
    source = "./modules/ecs"
    service_name = "${var.service_name}"
    image = "${module.ecr.repository_url}:latest"
    container_port = var.container_port
    subnet_ids = module.network.subnet_ids
    security_group_ids = [module.network.security_group_id]
    execution_role_arn = data.aws_iam_role.lab_role.arn
    task_role_arn = data.aws_iam_role.lab_role.arn
    log_group_name = module.logging.log_group_name
    ecs_count = var.ecs_count
    region = var.aws_region

    # Environment variables
    environment_variables = [
        {
            name  = "SNS_TOPIC_ARN"
            value = module.sns.topic_arn
        },
        {
            name  = "AWS_REGION"
            value = var.aws_region
        },
        {
            name = "DYNAMO_TABLE"
            value = var.dynamo_table
        },
        {
            name = "POST_STRATEGY"
            value = var.post_strategy
        },
        {
            name = "SOCIAL_GRAPH_URL"
            value = var.social_graph_url
        },
    ]

}

# Build & Push Receiver image to ECR
resource "docker_image" "app" {
    name = "${module.ecr.repository_url}:latest"
    build {
        context = "../"  
    }
}

resource "docker_registry_image" "app" {
    name = docker_image.app.name
}


