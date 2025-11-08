# Carts table - stores shopping cart information
resource "aws_dynamodb_table" "posts" {
  name           = var.table_name
  billing_mode   = "PAY_PER_REQUEST"  # On-demand pricing
  hash_key       = "post_id"

  attribute {
    name = "post_id"
    type = "S"
  }

  tags = {
    Name        = var.table_name
    Environment = var.environment
  }
}
