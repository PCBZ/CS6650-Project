FROM --platform=linux/amd64 golang:1.24-alpine AS builder

WORKDIR /build

# Install dependencies
RUN apk add --no-cache git

# Copy root proto directory FIRST (for shared proto files)
COPY proto/ ./proto/

# Copy social-graph-services directory structure
COPY services/social-graph-services/ ./services/social-graph-services/

# Set working directory to social-graph-services
WORKDIR /build/services/social-graph-services

# Download dependencies (now relative paths work correctly)
RUN go mod download

# Build the main application
RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o social-graph-service ./src

# Final image
FROM --platform=linux/amd64 alpine:latest

RUN apk --no-cache add ca-certificates

WORKDIR /root/

# Copy binary from builder
COPY --from=builder /build/services/social-graph-services/social-graph-service .

# Environment variables (will be overridden by ECS environment)
ENV HTTP_PORT=8085
ENV GRPC_PORT=50052
ENV AWS_REGION=us-west-2

EXPOSE 8085 50052

CMD ["./social-graph-service"]
