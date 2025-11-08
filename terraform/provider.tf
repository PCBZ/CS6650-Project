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
  # Will use [default] profile from ~/.aws/credentials
}

# Docker provider with ECR authentication
provider "docker" {
  registry_auth {
    address  = "${var.aws_account_id}.dkr.ecr.${var.aws_region}.amazonaws.com"
    username = "AWS"
    password = data.aws_ecr_authorization_token.token.password
  }
}

# Get ECR authorization token
data "aws_ecr_authorization_token" "token" {
  registry_id = var.aws_account_id
}
