# Create (or ensure) an ECR repo exists
resource "aws_ecr_repository" "this" {
    name = var.respository_name
}