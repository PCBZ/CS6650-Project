# ===================================
# DynamoDB Table for Timeline Service
# Stores Post Content
# ===================================

resource "aws_dynamodb_table" "posts" {
  name           = "posts-${var.environment}"
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
    name = "author_id"
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
    Name        = "Posts-${var.environment}"
    Environment = var.environment
    Service     = "timeline-service"
  }
}

# ===================================
# Outputs
# ===================================

output "posts_table_name" {
  value       = aws_dynamodb_table.posts.name
  description = "Posts table name"
}

output "posts_table_arn" {
  value       = aws_dynamodb_table.posts.arn
  description = "Posts table ARN"
}

output "posts_stream_arn" {
  value       = aws_dynamodb_table.posts.stream_arn
  description = "Posts table stream ARN"
}
