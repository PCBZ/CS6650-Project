terraform {
  required_version = ">= 1.0"

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

provider "aws" {
  region = var.aws_region
}

# ECR authorization token requires permissions not available in AWS learner lab
# You'll need to authenticate to ECR manually using AWS CLI:
# aws ecr get-login-password --region <region> | docker login --username AWS --password-stdin <account_id>.dkr.ecr.<region>.amazonaws.com

# Get ECR authorization token
# data "aws_ecr_authorization_token" "token" {}

# Configure Docker provider to authenticate with ECR
# provider "docker" {
#   registry_auth {
#     address  = data.aws_ecr_authorization_token.token.proxy_endpoint
#     username = data.aws_ecr_authorization_token.token.user_name
#     password = data.aws_ecr_authorization_token.token.password
#   }
# }
