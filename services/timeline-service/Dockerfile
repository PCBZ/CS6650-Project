FROM --platform=linux/amd64 golang:1.25.1-alpine AS builder

WORKDIR /build

# Install build deps
RUN apk add --no-cache git

# Speed up and stabilize module download
ENV GOPROXY=https://proxy.golang.org,direct

# 1) 先拷贝 proto（go.mod 使用 replace ../../proto，需先存在）
COPY proto/ ./proto/

# 2) 仅拷贝依赖声明，最大化缓存 go mod 层
WORKDIR /build/services/timeline-service
COPY services/timeline-service/go.mod services/timeline-service/go.sum ./
RUN go mod download

# 3) 拷贝源码并构建
COPY services/timeline-service/ ./ 
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -a -installsuffix cgo -o timeline-service ./src

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
