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
export AWS_REGION=us-west-2
export GRPC_PORT=50052
export FOLLOWERS_TABLE=social-graph-followers
export FOLLOWING_TABLE=social-graph-following
./social-graph-service
```

## Docker

### Build Docker Image

```bash
# From project root
docker build -f services/social-graph-services/Dockerfile -t social-graph-service .
```

### Run Docker Container

```bash
docker run -p 50052:50052 \
  -e AWS_REGION=us-west-2 \
  -e FOLLOWERS_TABLE=social-graph-followers \
  -e FOLLOWING_TABLE=social-graph-following \
  social-graph-service
```

## Testing

### Run Test Data Generator

```bash
cd services/social-graph-services/scripts
python -m pip install -r requirements.txt
python tests/generate_test_local.py --num-users 299
```

### Run Tests

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
| `AWS_REGION` | `us-east-1` | AWS region for DynamoDB |
| `GRPC_PORT` | `50051` | gRPC server port |
| `FOLLOWERS_TABLE` | `FollowersTable` | DynamoDB table for followers |
| `FOLLOWING_TABLE` | `FollowingTable` | DynamoDB table for following |

## API Endpoints

The service exposes the following gRPC methods:

- `FollowUser` - Create a follow relationship
- `UnfollowUser` - Remove a follow relationship
- `GetFollowers` - Get list of followers with pagination
- `GetFollowing` - Get list of users being followed with pagination
- `GetFollowerCount` - Get total follower count
- `GetFollowingCount` - Get total following count
- `CheckFollowRelationship` - Check if a follow relationship exists

## DynamoDB Schema

### Followers Table
- Primary Key: `user_id` (String) - The user being followed
- Attributes: `followers` (String Set) - Set of follower user IDs

### Following Table
- Primary Key: `user_id` (String) - The user doing the following
- Attributes: `following` (String Set) - Set of followed user IDs

## Integration

This service is designed to work with:
- **User Service** (port 8080) - User management
- **Post Service** (port 8083) - Post creation and fanout
- **Timeline Service** (port 8084) - Timeline generation

Service discovery is handled via AWS ECS Service Connect.
