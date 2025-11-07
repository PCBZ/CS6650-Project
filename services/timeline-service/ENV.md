# Timeline Service Environment Variables

## Required Environment Variables

### Server Configuration
- `TIMELINE_SERVICE_PORT`: Service port (default: 8084)
- `ENVIRONMENT`: Deployment environment (dev/staging/prod)

### AWS Configuration
- `AWS_REGION`: AWS region (default: us-east-1)
- `DYNAMODB_POSTS_TABLE`: DynamoDB table name for posts
- `SQS_QUEUE_URL`: SQS queue URL for feed messages

### Service Integration
- `USER_SERVICE_ENDPOINT`: User Service HTTP endpoint for gRPC-style calls
  - `mock`: Use mock client (development)
  - `http://user-service:8080`: Real User Service endpoint
- `POST_SERVICE_ENDPOINT`: Post Service HTTP endpoint
  - `mock`: Use mock client (development)  
  - `http://post-service:8081`: Real Post Service endpoint
- `SOCIAL_GRAPH_SERVICE_ENDPOINT`: Social Graph Service HTTP endpoint
  - `mock`: Use mock client (development)
  - `http://social-graph-service:8082`: Real Social Graph Service endpoint

### Fan-out Strategy Configuration
- `FANOUT_STRATEGY`: Strategy to use (push/pull/hybrid) - **Required**
  - `push`: Pre-compute timelines in DynamoDB
  - `pull`: Fetch posts on-demand via gRPC
  - `hybrid`: Route based on follower count
- `CELEBRITY_THRESHOLD`: Follower count threshold for hybrid strategy (default: 50000)

### Logging
- `LOG_LEVEL`: Log level (debug/info/warn/error)

## Example Configurations

### Push Strategy (Default)
```env
FANOUT_STRATEGY=push
DYNAMODB_POSTS_TABLE=posts-prod
USER_SERVICE_ENDPOINT=http://user-service:8080
POST_SERVICE_ENDPOINT=http://post-service:8081
SOCIAL_GRAPH_SERVICE_ENDPOINT=http://social-graph-service:8082
```

### Pull Strategy
```env
FANOUT_STRATEGY=pull
USER_SERVICE_ENDPOINT=http://user-service:8080
POST_SERVICE_ENDPOINT=http://post-service:8081
SOCIAL_GRAPH_SERVICE_ENDPOINT=http://social-graph-service:8082
# DynamoDB not required for pull strategy
```

### Hybrid Strategy
```env
FANOUT_STRATEGY=hybrid
CELEBRITY_THRESHOLD=100000
DYNAMODB_POSTS_TABLE=posts-prod
USER_SERVICE_ENDPOINT=http://user-service:8080
POST_SERVICE_ENDPOINT=http://post-service:8081
SOCIAL_GRAPH_SERVICE_ENDPOINT=http://social-graph-service:8082
```

### Development with Mock Services
```env
FANOUT_STRATEGY=push
USER_SERVICE_ENDPOINT=mock
POST_SERVICE_ENDPOINT=mock
SOCIAL_GRAPH_SERVICE_ENDPOINT=mock
```

## Docker Usage

### Build and run with default settings:
```bash
docker build -t timeline-service .
docker run -p 8084:8084 timeline-service
```

### Override strategy at runtime:
```bash
docker run -p 8084:8084 \
  -e FANOUT_STRATEGY=hybrid \
  -e CELEBRITY_THRESHOLD=75000 \
  timeline-service
```

### Using docker-compose:
```bash
# Edit docker-compose.yml to set environment variables
docker-compose up
```

## API Endpoints

Timeline Service provides the following endpoints:

- `GET /api/timeline/:user_id` - Retrieve user's timeline
- `GET /api/health` - Service health check

Note: Timeline Service processes fanout messages asynchronously via SQS, not HTTP endpoints.

## Health Check

Check current configuration:
```bash
curl http://localhost:8084/api/health
```

Response includes current strategy and service info:
```json
{
  "status": "healthy",
  "service": "timeline-service",
  "current_strategy": "push",
  "available_strategies": ["push", "pull", "hybrid"],
  "message_processing": "SQS-based async processing",
  "endpoints": {
    "timeline": "GET /api/timeline/:user_id",
    "health": "GET /api/health"
  }
}
```