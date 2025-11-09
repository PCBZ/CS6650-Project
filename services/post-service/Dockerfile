# Build stage
FROM --platform=linux/amd64 golang:1.25.1-alpine AS builder

WORKDIR /build/services/post-service

# Copy proto dependencies first (go.mod expects ../../proto from services/post-service)
COPY proto/ ../../proto/

# Copy post-service go.mod files
COPY services/post-service/go.mod services/post-service/go.sum ./
RUN go mod download

# Copy post-service source code
COPY services/post-service/ ./

# Build the application for AMD64
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -a -installsuffix cgo -o post-service ./cmd 

# Final stage
FROM --platform=linux/amd64 alpine:latest

# Install ca-certificates for HTTPS requests
RUN apk --no-cache add ca-certificates

WORKDIR /root/

# Copy the binary from builder stage
COPY --from=builder /build/services/post-service/post-service .

# Expose both HTTP and gRPC ports
EXPOSE 8083 50053

# Command to run
CMD ["./post-service"]
