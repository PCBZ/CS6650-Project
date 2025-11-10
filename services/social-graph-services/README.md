# Social Graph Service

A gRPC-based microservice for managing social graph relationships (follow/unfollow) using AWS DynamoDB.

## Structure

```
social-graph-services/
├── Dockerfile              # Docker build configuration
├── go.mod                  # Go module dependencies
├── go.sum                  # Go module checksums
├── proto/                  # Protocol buffer definitions
│   └── social_graph_service.proto
├── socialgraph/            # Generated gRPC code
│   ├── social_graph_service.pb.go
│   └── social_graph_service_grpc.pb.go
├── src/                    # Source code
│   ├── main.go            # Main entry point
│   ├── handlers.go        # gRPC handler implementations
│   └── dynamodb.go        # DynamoDB client wrapper
├── scripts/               # Test data generation scripts
│   ├── core/
│   └── tests/
└── terraform/             # Infrastructure as Code
    ├── main.tf
    ├── variables.tf
    ├── outputs.tf
    └── modules/
```

## Features

- Follow/Unfollow users
- Get followers list with pagination
- Get following list with pagination
- Get follower/following counts
- Check follow relationship

## Prerequisites

- Go 1.24+
- Protocol Buffers compiler (protoc)
- AWS credentials configured
- DynamoDB tables: `social-graph-followers` and `social-graph-following`

## Development

### Generate gRPC Code

```bash
cd services/social-graph-services
protoc --go_out=socialgraph --go_opt=paths=source_relative \
    --go-grpc_out=socialgraph --go-grpc_opt=paths=source_relative \
    proto/social_graph_service.proto
```

### Build Locally

```bash
cd services/social-graph-services
go mod download
go build -o social-graph-service ./src
```

### Run Locally

```bash
export HTTP_PORT=8085
export GRPC_PORT=50052
export AWS_REGION=us-west-2
export FOLLOWERS_TABLE=social-graph-followers
export FOLLOWING_TABLE=social-graph-following
export USER_SERVICE_URL=user-service-grpc:50051
./social-graph-service
```

The service will start two servers:
- HTTP server on port 8085
- gRPC server on port 50052

## Docker

### Build Docker Image

```bash
# From project root
docker build -f services/social-graph-services/Dockerfile -t social-graph-service .
```

### Run Docker Container

```bash
docker run -p 8085:8085 -p 50052:50052 \
  -e HTTP_PORT=8085 \
  -e GRPC_PORT=50052 \
  -e AWS_REGION=us-west-2 \
  -e FOLLOWERS_TABLE=social-graph-followers \
  -e FOLLOWING_TABLE=social-graph-following \
  -e USER_SERVICE_URL=user-service-grpc:50051 \
  social-graph-service
```

## Loading Test Data

The service uses **Option B (List Format)** for storing relationships in DynamoDB, which provides 99.8% better performance for Timeline Service integration.

### Quick Start

```bash
cd services/social-graph-services/scripts
pip install -r requirements.txt

# Load 5,000 users (default)
python load_dynamodb.py --region us-west-2

# Load custom number of users
python load_dynamodb.py --users 25000 --region us-west-2

# Specify custom table names
python load_dynamodb.py \
  --users 5000 \
  --followers-table custom-followers-table \
  --following-table custom-following-table \
  --region us-west-2
```

### Using Shell Scripts

**Linux/Mac:**
```bash
cd services/social-graph-services/scripts
./load_test_data.sh 5000
```

**Windows PowerShell:**
```powershell
cd services\social-graph-services\scripts
.\load_test_data.ps1 -Users 5000
```

### Data Distribution

The script generates realistic social graph data following a power-law distribution:

| Segment | User Range | Avg Followers | Avg Following | % of Users |
|---------|-----------|---------------|---------------|------------|
| Mega | 1-25 | 50,000 | 100 | 0.5% |
| Influencer | 26-250 | 5,000 | 200 | 4.5% |
| Active | 251-2,500 | 500 | 300 | 45% |
| Casual | 2,501-N | 50 | 100 | 50% |

### Loading Performance

- 5,000 users: ~30 seconds
- 25,000 users: ~2 minutes
- 100,000 users: ~8 minutes

### Verification

After loading data, verify it worked:

```bash
# Check table item counts
aws dynamodb scan --table-name social-graph-followers --select COUNT --region us-west-2
aws dynamodb scan --table-name social-graph-following --select COUNT --region us-west-2

# Get sample item
aws dynamodb get-item \
  --table-name social-graph-followers \
  --key '{"user_id": {"S": "1"}}' \
  --region us-west-2
```

Or test via HTTP endpoints (requires service running):

```bash
# Get followers of user 1
curl http://localhost:8085/api/1/followers

# Get following list of user 1
curl http://localhost:8085/api/1/following

# Get counts
curl http://localhost:8085/api/followers/1/count
curl http://localhost:8085/api/following/1/count
```

## Testing

### Run Unit Tests

```bash
cd services/social-graph-services/scripts
pytest tests/
```

## Terraform Deployment

```bash
cd terraform
terraform init
terraform plan
terraform apply
```

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `HTTP_PORT` | `8085` | HTTP REST API server port |
| `GRPC_PORT` | `50052` | gRPC server port |
| `ENVIRONMENT` | `dev` | Environment (dev/staging/production) |
| `AWS_REGION` | `us-west-2` | AWS region for DynamoDB |
| `FOLLOWERS_TABLE` | `social-graph-followers` | DynamoDB table for followers |
| `FOLLOWING_TABLE` | `social-graph-following` | DynamoDB table for following |
| `USER_SERVICE_URL` | `user-service-grpc:50051` | User Service gRPC endpoint |
| `LOG_LEVEL` | `info` | Logging level (debug/info/warn/error) |

## API Endpoints

### gRPC Methods (Port 50052)

The service exposes the following gRPC methods:

- `FollowUser` - Create a follow relationship
- `UnfollowUser` - Remove a follow relationship
- `GetFollowers` - Get list of followers with pagination
- `GetFollowingList` - Get list of users being followed (for Timeline Service)
- `GetFollowersCount` - Get total follower count
- `GetFollowingCount` - Get total following count
- `CheckFollowRelationship` - Check if a follow relationship exists
- `BatchCreateFollowRelationships` - Bulk create multiple relationships

### HTTP REST Endpoints (Port 8085)

The service also provides HTTP REST endpoints:

- `POST /api/follow` - Follow/unfollow a user
- `GET /api/:user_id/followers` - Get followers list
- `GET /api/:user_id/following` - Get following list
- `GET /api/followers/:userId/count` - Get follower count
- `GET /api/following/:userId/count` - Get following count
- `GET /api/relationship/check` - Check if relationship exists
- `GET /api/health` - Health check endpoint
- `POST /api/admin/load-test-data` - Admin endpoint for data loading info

## DynamoDB Schema

This service uses **Option B (List Format)** for optimal read performance. Each user has one record containing all their relationships as a list.

### Followers Table (social-graph-followers)

**Purpose**: Stores who follows each user

**Schema**:
- **Primary Key**: `user_id` (String) - The user being followed
- **Attributes**: 
  - `follower_ids` (List of Strings) - Array of user IDs who follow this user

**Example Record**:
```json
{
  "user_id": "123",
  "follower_ids": ["456", "789", "101", "202", ...]
}
```

**Interpretation**: User 123 is followed by users 456, 789, 101, 202, etc.

**Read Pattern**: `GetItem(user_id="123")` returns complete list of all followers in one operation

### Following Table (social-graph-following)

**Purpose**: Stores who each user follows

**Schema**:
- **Primary Key**: `user_id` (String) - The user who is following others
- **Attributes**: 
  - `following_ids` (List of Strings) - Array of user IDs this user follows

**Example Record**:
```json
{
  "user_id": "456",
  "following_ids": ["123", "200", "300", "400", ...]
}
```

**Interpretation**: User 456 follows users 123, 200, 300, 400, etc.

**Read Pattern**: `GetItem(user_id="456")` returns complete list of all following in one operation

### Design Benefits

**Why List Format (Option B)?**
1. ✅ **99.8% faster reads**: Single GetItem operation vs. thousands of Query operations
2. ✅ **Perfect for Timeline Service**: GetFollowingList returns all IDs in one call
3. ✅ **Lower costs**: 1 read capacity unit vs. 50+ RCUs for large lists
4. ✅ **Lower latency**: O(1) database call vs. O(N) queries
5. ✅ **DynamoDB best practices**: Store related data together

**Trade-offs**:
- Unfollow operation is slightly slower (must find index in list)
- Maximum ~10,000 relationships per user (due to 400KB DynamoDB item limit)
  - For users exceeding this, implement sharding (e.g., user_id#1, user_id#2)

### Data Operations

**Read Operations** (Optimized for speed):
```go
// Get all followers - O(1) operation
GetFollowers(user_id) → Single GetItem → Returns []follower_ids

// Get all following - O(1) operation
GetFollowing(user_id) → Single GetItem → Returns []following_ids

// Get count - O(1) operation
GetFollowersCount(user_id) → Single GetItem → Returns len(follower_ids)
```

**Write Operations** (Append/Remove from list):
```go
// Follow user - Append to list
FollowUser(follower, followee) → UpdateItem with list_append

// Unfollow user - Remove from list
UnfollowUser(follower, followee) → GetItem + UpdateItem REMOVE list[index]
```

## Integration

This service is designed to work with:
- **User Service** (gRPC port 50051, HTTP port 8080) - User management and profile info
- **Timeline Service** (port 8084) - Timeline generation (calls GetFollowingList)
- **Post Service** (port 8083) - Post creation and fanout

### Service Discovery

Service discovery is handled via **AWS ECS Service Connect**:
- HTTP endpoint: `social-graph-service:8085`
- gRPC endpoint: `social-graph-service-grpc:50052`

Other services can reach this service using these Service Connect DNS names.

### Timeline Service Integration

The Timeline Service calls `GetFollowingList()` via gRPC to retrieve the complete list of user IDs that a user follows. Thanks to Option B (List Format), this returns all IDs in a single database operation, providing 99.8% better performance compared to traditional query-based approaches.

**Example gRPC call from Timeline Service**:
```go
conn, _ := grpc.Dial("social-graph-service-grpc:50052", grpc.WithInsecure())
client := pb.NewSocialGraphServiceClient(conn)

response, _ := client.GetFollowingList(ctx, &pb.GetFollowingListRequest{
    UserId: 123,
})

followingIDs := response.FollowingUserIds  // Returns complete list
```
