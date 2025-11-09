# Proto Code Generation

This directory contains generated Protocol Buffer code. 

## Prerequisites

Install the required tools:

```powershell
# Install protoc compiler
choco install protoc

# Install Go plugins
go install google.golang.org/protobuf/cmd/protoc-gen-go@latest
go install google.golang.org/grpc/cmd/protoc-gen-go-grpc@latest
```

## Generate Code

Run from the service root directory:

```powershell
# Windows
.\generate_proto.ps1

# Linux/Mac
./generate_proto.sh
```

Or manually:

```bash
protoc --go_out=. --go_opt=paths=source_relative \
    --go-grpc_out=. --go-grpc_opt=paths=source_relative \
    proto/social_graph_service.proto
```

## Files

After generation, this directory will contain:
- `social_graph_service.pb.go` - Message definitions
- `social_graph_service_grpc.pb.go` - gRPC service definitions

## Note

These files are generated and should not be edited manually.
Add `*.pb.go` to `.gitignore` if you prefer to generate them during build.
