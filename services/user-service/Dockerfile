# Build stage
FROM --platform=linux/amd64 golang:1.25.1-alpine AS builder

WORKDIR /app

# Copy proto directory (build context is project root)
COPY proto/ proto/

# Copy user-service files
COPY services/user-service/go.mod services/user-service/go.sum ./

# Download dependencies
RUN go mod download

# Copy source code
COPY services/user-service/ .

# Build the application for AMD64
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -a -installsuffix cgo -o main .

# Final stage
FROM --platform=linux/amd64 alpine:latest

# Install ca-certificates for HTTPS requests
RUN apk --no-cache add ca-certificates

WORKDIR /root/

# Copy the binary from builder stage
COPY --from=builder /app/main .

# Expose both HTTP and gRPC ports
EXPOSE 8081 50051

# Command to run
CMD ["./main"]