# ECR Repository for service container images
resource "aws_ecr_repository" "this" {
  name         = var.repository_name
  force_delete = true

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name    = "${var.repository_name} ECR Repository"
    Service = var.repository_name
  }
}
