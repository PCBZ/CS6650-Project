FROM --platform=linux/amd64 golang:1.24-alpine AS builder

WORKDIR /build

# Install dependencies
RUN apk add --no-cache git

# Copy root proto directory FIRST (for shared proto files)
COPY proto/ ./proto/

# Copy timeline-service directory structure
COPY services/timeline-service/ ./services/timeline-service/

# Set working directory to timeline-service
WORKDIR /build/services/timeline-service

# Download dependencies (now relative paths work correctly)
RUN go mod download

# Build the main application
RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o timeline-service ./src

# Final image
FROM --platform=linux/amd64 alpine:latest

RUN apk --no-cache add ca-certificates

WORKDIR /root/

# Copy binary from builder
COPY --from=builder /build/services/timeline-service/timeline-service .

# Environment variables (will be overridden by ECS environment)
ENV PORT=8084
ENV AWS_REGION=us-west-2

EXPOSE 8084

CMD ["./timeline-service"]
