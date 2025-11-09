# IAM Roles for ECS Tasks (Innovation Sandbox requires ISBStudent=true tag)
module "iam" {
  source = "./modules/iam"
  
  project_name   = var.project_name
  environment    = var.environment
  aws_region     = var.aws_region
  aws_account_id = data.aws_caller_identity.current.account_id
}

# Shared VPC and Networking
module "network" {
  source = "./modules/network"
  
  project_name = var.project_name
  environment  = var.environment
  
  vpc_cidr             = var.vpc_cidr
  availability_zones   = var.availability_zones
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
}

# Shared Application Load Balancer
module "alb" {
  source = "./modules/alb"
  
  project_name       = var.project_name
  environment        = var.environment
  vpc_id            = module.network.vpc_id
  public_subnet_ids = module.network.public_subnet_ids
  security_group_id = module.network.alb_security_group_id
}

# Shared RDS PostgreSQL Instance
module "rds" {
  source = "./modules/rds"
  
  project_name         = var.project_name
  environment          = var.environment
  vpc_id              = module.network.vpc_id
  vpc_cidr            = module.network.vpc_cidr
  private_subnet_ids  = module.network.private_subnet_ids
  app_security_group_ids = [] # Will be populated by services
  
  master_username = var.rds_master_username
  master_password = var.rds_master_password
  instance_class  = var.rds_instance_class
  backup_retention_period = var.rds_backup_retention_period
}

# User Service
module "user_service" {
  source = "../services/user-service/terraform"
  
  # Shared infrastructure values
  vpc_id                = module.network.vpc_id
  vpc_cidr              = module.network.vpc_cidr
  public_subnet_ids     = module.network.public_subnet_ids
  private_subnet_ids    = module.network.private_subnet_ids
  alb_listener_arn      = module.alb.listener_arn
  alb_arn_suffix        = module.alb.alb_arn_suffix
  rds_address           = module.rds.db_address
  rds_port              = module.rds.db_port
  rds_security_group_id = module.rds.security_group_id
  service_connect_namespace_arn = module.network.service_connect_namespace_arn
  
  # IAM role for ECS tasks
  execution_role_arn = module.iam.ecs_task_execution_role_arn
  
  # Pass through necessary variables
  aws_region           = var.aws_region
  service_name         = "user-service"
  ecr_repository_name  = "user-service"
  container_port       = 8080
  ecs_count           = var.user_service_ecs_count
  alb_priority        = 100  # Higher priority for specific path
  database_name       = var.user_service_database_name
  rds_master_password = var.rds_master_password
  
  # Auto-scaling settings
  min_capacity                 = var.user_service_min_capacity
  max_capacity                = var.user_service_max_capacity
  cpu_target_value            = var.user_service_cpu_target_value
  memory_target_value         = var.user_service_memory_target_value
  enable_request_based_scaling = var.user_service_enable_request_based_scaling
  request_count_target_value  = var.user_service_request_count_target_value
}

# Web Service
module "web_service" {
  source = "../web-service/terraform"
  
  # Shared infrastructure values
  vpc_id            = module.network.vpc_id
  vpc_cidr          = module.network.vpc_cidr
  public_subnet_ids = module.network.public_subnet_ids
  alb_listener_arn  = module.alb.listener_arn
  alb_arn_suffix    = module.alb.alb_arn_suffix
  alb_dns_name      = module.alb.alb_dns_name
  service_connect_namespace_arn = module.network.service_connect_namespace_arn
  
  # IAM role for ECS tasks
  execution_role_arn = module.iam.ecs_task_execution_role_arn
  
  # Pass through necessary variables
  aws_region          = var.aws_region
  service_name        = "web-service"
  ecr_repository_name = "web-service"
  container_port      = 8081
  ecs_count          = var.web_service_ecs_count
  alb_priority       = 200  # Lower priority for catch-all
  # Use Service Connect for internal HTTP communication
  user_service_url   = "http://user-service:8080"
  
  # Use Service Connect for gRPC communication (proper service discovery!)
  user_service_grpc_host = "user-service-grpc:50051"
  user_service_security_group_id = module.user_service.security_group_id
  
  # Post Service URL (via Service Connect)
  post_service_url = "http://post-service:8083"
  post_service_grpc_host = "post-service-grpc:50053"
  
  # Timeline Service URL
  timeline_service_url = "http://timeline-service:8084"
  
  # Auto-scaling settings
  min_capacity                 = var.web_service_min_capacity
  max_capacity                = var.web_service_max_capacity
  cpu_target_value            = var.web_service_cpu_target_value
  memory_target_value         = var.web_service_memory_target_value
  enable_request_based_scaling = var.web_service_enable_request_based_scaling
  request_count_target_value  = var.web_service_request_count_target_value
  
  # Ensure post-service is deployed before web-service starts
  # This helps with Service Connect DNS registration timing
  depends_on = [module.post_service]
}

# Post Service
module "post_service" {
  source = "../services/post-service/terraform"
  
  # Shared infrastructure values
  vpc_id                = module.network.vpc_id
  vpc_cidr              = module.network.vpc_cidr
  public_subnet_ids     = module.network.public_subnet_ids
  private_subnet_ids    = module.network.private_subnet_ids
  alb_listener_arn      = module.alb.listener_arn
  alb_arn_suffix        = module.alb.alb_arn_suffix
  service_connect_namespace_arn = module.network.service_connect_namespace_arn
  
  # IAM role for ECS tasks
  execution_role_arn = module.iam.ecs_task_execution_role_arn
  task_role_arn      = module.iam.post_service_task_role_arn
  
  # Pass through necessary variables
  aws_region           = var.aws_region
  service_name         = "post-service"
  ecr_repository_name  = "post-service"
  container_port       = 8083
  ecs_count           = var.post_service_ecs_count
  alb_priority        = 300  # Post service priority 
  
  # Post Service specific configuration
  social_graph_url  = "social-graph-service-grpc:50052"
  post_strategy           = var.post_service_post_strategy
  
  # Auto-scaling settings
  min_capacity                = var.post_service_min_capacity
  max_capacity                = var.post_service_max_capacity
  cpu_target_value            = var.post_service_cpu_target_value
  memory_target_value         = var.post_service_memory_target_value
  enable_request_based_scaling = var.post_service_enable_request_based_scaling
  request_count_target_value  = var.post_service_request_count_target_value
}

# Timeline Service
module "timeline_service" {
  source = "../services/timeline-service/terraform"
  
  # Shared infrastructure values
  vpc_id                = module.network.vpc_id
  vpc_cidr              = module.network.vpc_cidr
  public_subnet_ids     = module.network.public_subnet_ids
  private_subnet_ids    = module.network.private_subnet_ids
  alb_listener_arn      = module.alb.listener_arn
  alb_arn_suffix        = module.alb.alb_arn_suffix
  service_connect_namespace_arn = module.network.service_connect_namespace_arn
  
  # IAM role for ECS tasks
  execution_role_arn = module.iam.ecs_task_execution_role_arn
  task_role_arn      = module.iam.timeline_service_task_role_arn
  
  # Pass through necessary variables
  aws_region           = var.aws_region
  service_name         = "timeline-service"
  ecr_repository_name  = "timeline-service"
  container_port       = 8084
  ecs_count           = var.timeline_service_ecs_count
  alb_priority        = 400  # Timeline service priority
  
  # Timeline Service specific configuration
  post_service_url          = "post-service-grpc:50053"
  social_graph_service_url  = "social-graph-service-grpc:50052"
  user_service_url          = "user-service-grpc:50051"
  fanout_strategy           = var.timeline_service_fanout_strategy
  celebrity_threshold       = var.timeline_service_celebrity_threshold
  enable_pitr               = var.timeline_service_enable_pitr
  
  # Auto-fetch SNS topic ARN from post-service module
  post_service_sns_topic_arn = module.post_service.sns_topic_arn
  
  # Auto-scaling settings
  min_capacity                 = var.timeline_service_min_capacity
  max_capacity                = var.timeline_service_max_capacity
  cpu_target_value            = var.timeline_service_cpu_target_value
  memory_target_value         = var.timeline_service_memory_target_value
  enable_request_based_scaling = var.timeline_service_enable_request_based_scaling
  request_count_target_value  = var.timeline_service_request_count_target_value
}

# Social Graph Service
module "social_graph_service" {
  source = "../services/social-graph-services/terraform"
  
  # Shared infrastructure values
  vpc_id                = module.network.vpc_id
  vpc_cidr              = module.network.vpc_cidr
  public_subnet_ids     = module.network.public_subnet_ids
  private_subnet_ids    = module.network.private_subnet_ids
  alb_listener_arn      = module.alb.listener_arn
  alb_arn_suffix        = module.alb.alb_arn_suffix
  service_connect_namespace_arn = module.network.service_connect_namespace_arn
  
  # IAM roles for ECS tasks
  execution_role_arn = module.iam.ecs_task_execution_role_arn
  task_role_arn      = module.iam.social_graph_service_task_role_arn
  
  # Pass through necessary variables
  aws_region           = var.aws_region
  service_name         = "social-graph-service"
  ecr_repository_name  = "social-graph-service"
  container_port       = 8085
  ecs_desired_count    = var.social_graph_service_ecs_count
  alb_priority         = 150  # Social graph service priority
  
  # DynamoDB table names
  followers_table_name = "social-graph-followers"
  following_table_name = "social-graph-following"
  
  # Auto-scaling settings
  min_capacity                 = var.social_graph_service_min_capacity
  max_capacity                 = var.social_graph_service_max_capacity
  cpu_target_value             = var.social_graph_service_cpu_target_value
  memory_target_value          = var.social_graph_service_memory_target_value
  enable_request_based_scaling = var.social_graph_service_enable_request_based_scaling
  request_count_target_value   = var.social_graph_service_request_count_target_value
}