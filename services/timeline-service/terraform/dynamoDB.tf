# ===================================
# DynamoDB Table for Timeline Service
# Stores Post Content for Push strategy
# ===================================

resource "aws_dynamodb_table" "posts" {
  name           = "posts-${var.service_name}"
  billing_mode   = "PAY_PER_REQUEST"
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
    name = "created_at"
    type = "S"
  }

  # GSI for querying user's timeline (for push strategy)
  global_secondary_index {
    name            = "UserPostsIndex"
    hash_key        = "user_id"
    range_key       = "created_at"
    projection_type = "ALL"
    read_capacity   = 0
    write_capacity  = 0
  }

  point_in_time_recovery {
    enabled = var.enable_pitr
  }

  stream_enabled   = true
  stream_view_type = "NEW_AND_OLD_IMAGES"

  tags = {
    Name    = "Posts-${var.service_name}"
    Service = var.service_name
  }
}
