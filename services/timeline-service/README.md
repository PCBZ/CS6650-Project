# Timeline Service README

## Project Structure

```
timeline-service/
├── src/
│   ├── config/          # Configuration management
│   ├── db/              # Database connections (DynamoDB)
│   ├── fanout/          # Fan-out algorithm implementations
│   │   ├── interface.go # Strategy interface
│   │   ├── push.go      # Push (fan-out on write)
│   │   ├── pull.go      # Pull (fan-out on read)
│   │   └── hybrid.go    # Hybrid strategy
│   ├── handlers/        # HTTP request handlers
│   ├── models/          # Data models
│   └── main.go          # Entry point
├── terraform/           # IaC for AWS resources
├── go.mod              # Go module definition
└── Dockerfile          # Docker container image
```

## Features

✅ **Three Fan-out Algorithms**
- **Push Model**: Pre-compute timelines when posts are created
- **Pull Model**: Fetch posts on-demand when users request timeline
- **Hybrid Model**: Combination approach based on user type

✅ **High Performance**
- DynamoDB for scalable storage
- Batch processing for push operations
- GSI indexing for efficient queries

✅ **Monitoring**
- Structured JSON logging
- Configurable log levels
- Health check endpoint

## Setup

### Prerequisites

```bash
# Go 1.21+
go version

# AWS CLI configured
aws configure
```

### Local Development

```bash
# Install dependencies
go mod download

# Set environment variables
export ENVIRONMENT=dev
export AWS_REGION=us-east-1
export DYNAMODB_POSTS_TABLE=posts-dev
export FANOUT_STRATEGY=push
export TIMELINE_SERVICE_PORT=8084

# Run server
go run src/main.go
```

### Docker Build & Run

```bash
# Build image
docker build -t timeline-service:latest .

# Run container
docker run -p 8084:8084 \
  -e AWS_REGION=us-east-1 \
  -e DYNAMODB_POSTS_TABLE=posts-dev \
  -e FANOUT_STRATEGY=push \
  timeline-service:latest
```

## API Endpoints

### 1. Get Timeline
```
GET /api/timeline/:user_id?algorithm=push&limit=50

Response:
{
  "timeline": [
    {
      "post_id": "post_123",
      "user_id": 100,
      "username": "alice",
      "content": "Hello World",
      "created_at": "2025-11-05T20:00:00Z"
    }
  ],
  "total_count": 1,
  "has_more": false
}
```

### 2. Fan-out Post
```
POST /api/fanout

Body:
{
  "post": {
    "post_id": "post_123",
    "user_id": 100,
    "username": "alice",
    "content": "Hello World"
  },
  "follower_ids": [1, 2, 3],
  "algorithm": "push"
}

Response:
{
  "message": "Post fanned out successfully",
  "algorithm": "push"
}
```

### 3. Health Check
```
GET /api/health

Response:
{
  "status": "healthy",
  "strategies": ["push", "pull", "hybrid"]
}
```

## Configuration

Environment variables:

| Variable | Description | Default |
|----------|-------------|---------|
| `ENVIRONMENT` | Environment (dev/staging/prod) | `dev` |
| `LOG_LEVEL` | Logging level (debug/info/warn/error) | `info` |
| `TIMELINE_SERVICE_PORT` | Service port | `8084` |
| `AWS_REGION` | AWS region | `us-east-1` |
| `DYNAMODB_POSTS_TABLE` | DynamoDB table name | `posts-dev` |
| `FANOUT_STRATEGY` | Strategy to use | `push` |
| `CELEBRITY_THRESHOLD` | Follower threshold for celebrity | `50000` |

## Testing

### Test Push Strategy
```bash
curl -X GET "http://localhost:8084/api/timeline/123?algorithm=push&limit=10"
```

### Test Pull Strategy
```bash
curl -X GET "http://localhost:8084/api/timeline/123?algorithm=pull&limit=10"
```

### Test Hybrid Strategy
```bash
curl -X GET "http://localhost:8084/api/timeline/123?algorithm=hybrid&limit=10"
```

### Fan-out a Post
```bash
curl -X POST "http://localhost:8084/api/fanout" \
  -H "Content-Type: application/json" \
  -d '{
    "post": {
      "post_id": "post_123",
      "user_id": 100,
      "username": "alice",
      "content": "Hello World"
    },
    "follower_ids": [1, 2, 3, 4, 5],
    "algorithm": "push"
  }'
```

## Performance Considerations

### Push Strategy
- ✅ Fast timeline reads (pre-computed)
- ❌ Slower post creation (must fan-out)
- ✅ Good for users with few followers
- ❌ High storage for celebrities

### Pull Strategy
- ❌ Slower timeline reads (must aggregate)
- ✅ Fast post creation (no fan-out)
- ❌ Bad for frequent timeline reads
- ✅ Low storage overhead

### Hybrid Strategy
- ✅ Balanced approach
- ✅ Good for mixed user types
- ✅ Pre-computed for regular users
- ✅ On-demand for celebrities

## Monitoring

### CloudWatch Metrics
- DynamoDB read/write units
- Request latency
- Error rates

### Log Format
```json
{
  "timestamp": "2025-11-05T20:15:30Z",
  "level": "info",
  "message": "Timeline Service starting",
  "environment": "dev",
  "strategy": "push",
  "port": 8084
}
```

## Deployment

### AWS ECS Deployment
See `../docs/deployment.md` for complete deployment guide.

### Scaling Considerations
- DynamoDB: Auto-scales with PAY_PER_REQUEST billing
- Application: Horizontally scale with ECS auto-scaling
- Network: Use Application Load Balancer for distribution

## Troubleshooting

### DynamoDB Connection Error
```bash
# Check AWS credentials
aws sts get-caller-identity

# Check DynamoDB table exists
aws dynamodb list-tables --region us-east-1
```

### High Latency Issues
- Check DynamoDB throughput metrics
- Review query patterns
- Consider GSI optimization

### Memory Issues
- Monitor Go runtime metrics
- Profile with pprof: `go tool pprof`

## Next Steps

1. Integrate with User Service (gRPC for user info)
2. Integrate with Social Graph Service (fetch followers)
3. Integrate with Post Service (receive fan-out events)
4. Add Redis caching layer
5. Implement metrics collection (Prometheus)
6. Load testing and performance tuning

## References

- [AWS DynamoDB Best Practices](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/best-practices.html)
- [Gin Web Framework](https://gin-gonic.com/)
- [AWS SDK for Go](https://aws.amazon.com/sdk-for-go/)
