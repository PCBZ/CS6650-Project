# DynamoDB Table Design for Social Graph Service

## Table 1: FollowersTable
Stores follower relationships (who follows whom)

### Schema
```
Table Name: FollowersTable
Partition Key: user_id (Number) - The user being followed
Sort Key: follower_id (Number) - The user who follows

Attributes:
- user_id: Number (PK)
- follower_id: Number (SK)
- created_at: Number (Unix timestamp)
- follower_username: String (optional, for display)
```

### Access Patterns
1. Get all followers of a user: Query by `user_id`
2. Count followers: Query by `user_id` with count
3. Check if A follows B: Query by `user_id` and `follower_id`

### GSI (Global Secondary Index)
```
Index Name: FollowerUserIdIndex
Partition Key: follower_id
Sort Key: created_at

Purpose: Query all users that a specific user follows (reverse lookup)
```

---

## Table 2: FollowingTable
Stores following relationships (who a user follows)

### Schema
```
Table Name: FollowingTable
Partition Key: user_id (Number) - The user who follows
Sort Key: followee_id (Number) - The user being followed

Attributes:
- user_id: Number (PK)
- followee_id: Number (SK)
- created_at: Number (Unix timestamp)
- followee_username: String (optional, for display)
```

### Access Patterns
1. Get all users that a user follows: Query by `user_id`
2. Count following: Query by `user_id` with count
3. Check if A follows B: Query by `user_id` and `followee_id`

---

## Why Two Tables?

### Benefits
1. **Optimized Queries**: Each table is optimized for its specific query pattern
2. **Write Simplicity**: Insert/delete operations are straightforward
3. **Scalability**: Each table can scale independently
4. **Read Performance**: No need for complex filters or scans

### Trade-offs
- **Storage**: Duplicated data (each relationship stored twice)
- **Consistency**: Must ensure both tables are updated atomically
- **Cost**: Double the storage and write operations

### Cost Optimization
- Use **On-Demand Billing** for unpredictable workloads
- Consider **Provisioned Capacity** for predictable patterns
- Enable **Point-in-Time Recovery** for data safety

---

## Terraform Configuration

```hcl
# FollowersTable
resource "aws_dynamodb_table" "followers" {
  name           = "FollowersTable"
  billing_mode   = "PAY_PER_REQUEST"  # On-demand
  hash_key       = "user_id"
  range_key      = "follower_id"

  attribute {
    name = "user_id"
    type = "N"
  }

  attribute {
    name = "follower_id"
    type = "N"
  }

  attribute {
    name = "created_at"
    type = "N"
  }

  # GSI for reverse lookup
  global_secondary_index {
    name            = "FollowerUserIdIndex"
    hash_key        = "follower_id"
    range_key       = "created_at"
    projection_type = "ALL"
  }

  tags = {
    Name        = "FollowersTable"
    Environment = var.environment
    Service     = "social-graph"
  }
}

# FollowingTable
resource "aws_dynamodb_table" "following" {
  name           = "FollowingTable"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "user_id"
  range_key      = "followee_id"

  attribute {
    name = "user_id"
    type = "N"
  }

  attribute {
    name = "followee_id"
    type = "N"
  }

  attribute {
    name = "created_at"
    type = "N"
  }

  tags = {
    Name        = "FollowingTable"
    Environment = var.environment
    Service     = "social-graph"
  }
}
```

---

## Example Data

### FollowersTable
| user_id | follower_id | created_at | follower_username |
|---------|-------------|------------|-------------------|
| 12346   | 12345       | 1705318500 | user_12345        |
| 12346   | 12347       | 1705318501 | user_12347        |
| 12346   | 12348       | 1705318502 | user_12348        |

### FollowingTable
| user_id | followee_id | created_at | followee_username |
|---------|-------------|------------|-------------------|
| 12345   | 12346       | 1705318500 | user_12346        |
| 12345   | 12349       | 1705318503 | user_12349        |
| 12345   | 12350       | 1705318504 | user_12350        |
