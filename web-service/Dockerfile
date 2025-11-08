FROM --platform=linux/amd64 golang:1.25.1-alpine AS builder

WORKDIR /app

# Copy proto directory (build context is project root)
COPY proto/ proto/

# Copy web-service files
COPY web-service/go.mod web-service/go.sum ./
RUN go mod download

COPY web-service/ .
RUN CGO_ENABLED=0 GOOS=linux go build -o web-service .

FROM --platform=linux/amd64 alpine:latest

RUN apk --no-cache add ca-certificates
WORKDIR /root/

COPY --from=builder /app/web-service .

EXPOSE 3000

CMD ["./web-service"]
