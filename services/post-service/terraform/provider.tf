# Specify required providers (but don't configure them - inherit from parent)
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
  }
}

# ECR authorization token requires permissions not available in AWS learner lab
# You'll need to authenticate to ECR manually using AWS CLI:
# aws ecr get-login-password --region <region> | docker login --username AWS --password-stdin <account_id>.dkr.ecr.<region>.amazonaws.com

# Configure AWS credentials & region
#provider "aws" {
#  region     = var.aws_region
#}

# Fetch an ECR auth token so Terraform's Docker provider can log in
#data "aws_ecr_authorization_token" "registry" {}

# Configure Docker provider to authenticate against ECR automatically
# provider "docker" {
#   registry_auth {
#     address  = data.aws_ecr_authorization_token.registry.proxy_endpoint
#     username = data.aws_ecr_authorization_token.registry.user_name
#     password = data.aws_ecr_authorization_token.registry.password
#   }
# }