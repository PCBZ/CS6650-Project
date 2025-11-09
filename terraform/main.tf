# IAM Roles for ECS Tasks (Innovation Sandbox requires ISBStudent=true tag)
module "iam" {
  source = "./modules/iam"
  
  project_name   = var.project_name
  environment    = var.environment
  aws_region     = var.aws_region
  aws_account_id = var.aws_account_id
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
  is_windows           = var.is_windows
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
  is_windows          = var.is_windows
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
  
  # Auto-scaling settings
  min_capacity                 = var.web_service_min_capacity
  max_capacity                = var.web_service_max_capacity
  cpu_target_value            = var.web_service_cpu_target_value
  memory_target_value         = var.web_service_memory_target_value
  enable_request_based_scaling = var.web_service_enable_request_based_scaling
  request_count_target_value  = var.web_service_request_count_target_value
}

# Social Graph Service
module "social_graph_service" {
  source = "../services/social-graph-services/terraform"
  
  # Shared infrastructure values
  vpc_id                        = module.network.vpc_id
  vpc_cidr                      = module.network.vpc_cidr
  public_subnet_ids             = module.network.public_subnet_ids
  alb_listener_arn              = module.alb.listener_arn
  alb_arn_suffix                = module.alb.alb_arn_suffix
  service_connect_namespace_arn = module.network.service_connect_namespace_arn
  
  # IAM roles for ECS tasks
  execution_role_arn = module.iam.ecs_task_execution_role_arn
  task_role_arn      = module.iam.social_graph_task_role_arn
  
  # Service configuration
  aws_region           = var.aws_region
  is_windows           = var.is_windows
  service_name         = "social-graph"
  ecr_repository_name  = "social-graph-service"
  container_port       = 8080
  ecs_desired_count    = var.social_graph_ecs_count
  alb_priority         = 150  # Between user-service (100) and web-service (200)
  
  # DynamoDB table names
  dynamodb_table_name           = "social-graph-followers"
  dynamodb_following_table_name = "social-graph-following"
  
  # Auto-scaling settings
  min_capacity                 = var.social_graph_min_capacity
  max_capacity                 = var.social_graph_max_capacity
  cpu_target_value             = var.social_graph_cpu_target_value
  memory_target_value          = var.social_graph_memory_target_value
  enable_request_based_scaling = var.social_graph_enable_request_based_scaling
  request_count_target_value   = var.social_graph_request_count_target_value
  
  # Optional: DB connection (if social-graph needs RDS)
  db_host     = ""
  db_port     = ""
  db_name     = ""
  db_password = ""
}