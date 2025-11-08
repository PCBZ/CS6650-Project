FROM --platform=linux/amd64 golang:1.25.1-alpine AS builder

WORKDIR /build/web-service

# Copy proto dependencies first (go.mod expects ../proto from web-service)
COPY proto/ ../proto/

# Copy web-service go.mod files
COPY web-service/go.mod web-service/go.sum ./
RUN go mod download

# Copy ONLY the source code (main.go), NOT the entire directory
COPY web-service/main.go ./

RUN CGO_ENABLED=0 GOOS=linux go build -o web-service .

FROM alpine:latest

RUN apk --no-cache add ca-certificates
WORKDIR /root/

COPY --from=builder /build/web-service/web-service .

EXPOSE 3000

CMD ["./web-service"]
