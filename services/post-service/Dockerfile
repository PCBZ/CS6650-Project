# syntax=docker/dockerfile:1

FROM golang:1.25 AS build-stage

# Set destination for COPY
WORKDIR /app

# Download Go modules
COPY go.mod go.sum ./
RUN go mod download

# Copy the source code
COPY . ./

# Build the application
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -o /post-service ./cmd 

##
## Run the tests in the container
##

FROM build-stage AS run-test-stage
RUN go test -v ./...
##
## Deploy the application binary into a lean image
##

FROM gcr.io/distroless/base-debian11 AS build-release-stage

WORKDIR /

COPY --from=build-stage /post-service /post-service

EXPOSE 8082 50053

USER nonroot:nonroot

ENTRYPOINT ["/post-service"]
