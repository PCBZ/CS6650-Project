# Carts table - stores shopping cart information
resource "aws_dynamodb_table" "posts" {
  name           = var.table_name
  billing_mode   = "PAY_PER_REQUEST"  # On-demand pricing
  hash_key       = "post_id"

  attribute {
    name = "post_id"
    type = "S"
  }
  attribute {
    name = "user_id"
    type = "N"
  }
  attribute {
    name = "timestamp"
    type = "S"
  }

  # GSI for querying user's posts (for pull/hybrid strategy)
  global_secondary_index {
    name            = "user_id-index"
    hash_key        = "user_id"
    range_key       = "timestamp" 
    projection_type = "ALL"
    read_capacity   = 0
    write_capacity  = 0
  }


  tags = {
    Name        = var.table_name
    Environment = var.environment
  }
}
