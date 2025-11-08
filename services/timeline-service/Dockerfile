FROM --platform=linux/amd64 golang:1.24-alpine AS builder

WORKDIR /app

# Install dependencies
RUN apk add --no-cache git

# Copy timeline-service proto directory
COPY services/timeline-service/proto/ ./proto/

# Copy timeline-service files
COPY services/timeline-service/go.mod services/timeline-service/go.sum ./

# Download dependencies
RUN go mod download

# Copy source code
COPY services/timeline-service/src/ ./src/

# Build the main application
RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o timeline-service ./src

# Final image
FROM --platform=linux/amd64 alpine:latest

RUN apk --no-cache add ca-certificates

WORKDIR /root/

# Copy binary from builder
COPY --from=builder /app/timeline-service .

# Environment variables (will be overridden by ECS environment)
ENV PORT=8084
ENV AWS_REGION=us-west-2

EXPOSE 8084

CMD ["./timeline-service"]
