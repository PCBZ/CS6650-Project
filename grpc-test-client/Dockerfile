# Build stage
FROM golang:1.21-alpine AS builder

WORKDIR /app

# Copy go mod files
COPY go.mod go.sum ./
COPY ../proto/go.mod ../proto/go.sum ../proto/

# Download dependencies
RUN go mod download

# Copy source code
COPY . .
COPY ../proto ../proto

# Build the application
RUN CGO_ENABLED=0 GOOS=linux go build -o grpc-test-client .

# Run stage
FROM alpine:latest

WORKDIR /root/

# Copy the binary from builder
COPY --from=builder /app/grpc-test-client .

# Run the test client
# Default to user-service-grpc:50051 (Service Connect DNS name)
ENTRYPOINT ["./grpc-test-client"]
CMD ["-server", "user-service-grpc:50051", "-users", "1,2,3,4,5"]
