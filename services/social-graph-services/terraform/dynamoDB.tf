# ===================================
# DynamoDB Tables for Social Graph Service
# Stores follower/following relationships
# ===================================

# Followers Table: Maps user_id -> list of follower user IDs
resource "aws_dynamodb_table" "followers" {
  name         = var.followers_table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "user_id"

  attribute {
    name = "user_id"
    type = "S"
  }

  tags = {
    Name       = var.followers_table_name
    Service    = var.service_name
    ISBStudent = "true"
  }
}

# Following Table: Maps user_id -> list of following user IDs
resource "aws_dynamodb_table" "following" {
  name         = var.following_table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "user_id"

  attribute {
    name = "user_id"
    type = "S"
  }

  tags = {
    Name       = var.following_table_name
    Service    = var.service_name
    ISBStudent = "true"
  }
}
