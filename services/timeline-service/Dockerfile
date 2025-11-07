FROM golang:1.21-alpine AS builder

WORKDIR /app

# Install dependencies
RUN apk add --no-cache git

# Copy go mod files
COPY go.mod go.sum ./

# Download dependencies
RUN go mod download

# Copy source
COPY src/ ./src/

# Build
RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o timeline-service ./src/main.go

# Final image
FROM alpine:latest

RUN apk --no-cache add ca-certificates

WORKDIR /root/

# Copy binary from builder
COPY --from=builder /app/timeline-service .

# Copy env file
COPY .env .env

# Environment variables with default values
ENV TIMELINE_SERVICE_PORT=8084
ENV ENVIRONMENT=dev
ENV AWS_REGION=us-east-1
ENV DYNAMODB_POSTS_TABLE=posts-dev
ENV SQS_QUEUE_URL=https://sqs.us-east-1.amazonaws.com/123456789012/timeline-feed-queue
ENV USER_SERVICE_ENDPOINT=mock
ENV POST_SERVICE_ENDPOINT=mock
ENV SOCIAL_GRAPH_SERVICE_ENDPOINT=mock
ENV FANOUT_STRATEGY=push
ENV CELEBRITY_THRESHOLD=50000
ENV LOG_LEVEL=info

EXPOSE 8084

CMD ["./timeline-service"]
