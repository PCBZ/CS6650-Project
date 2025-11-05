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

# Shared RDS Aurora Cluster
module "rds" {
  source = "./modules/rds"
  
  project_name         = var.project_name
  environment          = var.environment
  vpc_id              = module.network.vpc_id
  private_subnet_ids  = module.network.private_subnet_ids
  app_security_group_ids = [] # Will be populated by services
  
  master_username = var.rds_master_username
  master_password = var.rds_master_password
  instance_class  = var.rds_instance_class
  backup_retention_period = var.rds_backup_retention_period
}