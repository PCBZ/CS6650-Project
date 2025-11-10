# User Validation for Social Graph Data Generation

## Overview

The new scripts (`load_dynamodb_with_validation.py`, `generate_and_load_validated.sh`, `load_test_data_validated.ps1`) validate that users exist in the user-service via gRPC `BatchGetUserInfo` before generating social graph relationships.

## Key Features

✅ **User Validation**: Fetches real user IDs from user-service via gRPC  
✅ **Batch Processing**: Scans users in batches of 100 (gRPC limit)  
✅ **Fallback Mode**: Can skip validation for testing with `--skip-validation`  
✅ **Smart Scanning**: Stops after 5 consecutive empty batches  
✅ **Cross-Platform**: Bash (Linux/macOS/WSL) and PowerShell (Windows)

## Usage

### Option 1: From VPC (ECS Task, Cloud9, Bastion)

When running from inside the VPC, use Service Connect DNS:

**Bash:**
```bash
./generate_and_load_validated.sh \
    --grpc-endpoint user-service-grpc:50051 \
    --max-users 5000
```

**PowerShell:**
```powershell
.\load_test_data_validated.ps1 `
    -GrpcEndpoint "user-service-grpc:50051" `
    -MaxUsers 5000
```

### Option 2: Via Port Forwarding

If you have port forwarding set up to your local machine:

**Bash:**
```bash
# First, set up port forward (in another terminal)
# aws ecs execute-command --cluster CLUSTER --task TASK --command "/bin/sh" --interactive
# or use AWS Systems Manager Session Manager

./generate_and_load_validated.sh \
    --grpc-endpoint localhost:50051 \
    --max-users 5000
```

**PowerShell:**
```powershell
.\load_test_data_validated.ps1 `
    -GrpcEndpoint "localhost:50051" `
    -MaxUsers 5000
```

### Option 3: Skip Validation (Testing Only)

For local testing or when user-service is not accessible:

**Bash:**
```bash
./generate_and_load_validated.sh \
    --skip-validation \
    --max-users 5000
```

**PowerShell:**
```powershell
.\load_test_data_validated.ps1 `
    -SkipValidation `
    -MaxUsers 5000
```

## How It Works

### 1. User Validation Phase

```python
# Scans users in batches of 100
batch_ids = [1, 2, 3, ..., 100]
response = stub.BatchGetUserInfo(batch_ids)

# Collects found user IDs
valid_users = [id for id in response.users.keys()]

# Continues until 5 consecutive empty batches
```

### 2. Relationship Generation

Uses the same power-law distribution as before, but only with validated user IDs:

```python
user_ids = [123, 145, 167, ...]  # From user-service
segmentation = UserSegmentation(len(user_ids))
segments = segmentation.segment_users(user_ids)
generator.generate_followers_first()
```

### 3. DynamoDB Loading

Same as before - batch writes to followers/following tables.

## Architecture

```
┌─────────────────────────────────────┐
│  generate_and_load_validated.sh     │
│  load_test_data_validated.ps1       │
└──────────────┬──────────────────────┘
               │
               ▼
┌─────────────────────────────────────┐
│ load_dynamodb_with_validation.py    │
└──────────────┬──────────────────────┘
               │
      ┌────────┴────────┐
      ▼                 ▼
┌───────────┐    ┌──────────────┐
│user-service│    │ core modules │
│  (gRPC)    │    │ - segmenter  │
│BatchGetUser│    │ - generator  │
│   Info     │    └──────┬───────┘
└─────┬──────┘           │
      │                  │
      └────────┬─────────┘
               ▼
        ┌──────────────┐
        │  DynamoDB    │
        │ - followers  │
        │ - following  │
        └──────────────┘
```

## Requirements

### Python Dependencies
```
grpcio>=1.60.0
grpcio-tools>=1.60.0
boto3>=1.34.0
requests>=2.31.0
```

### Proto Files
The script automatically generates Python proto files if needed:
```bash
cd proto/
python -m grpc_tools.protoc -I. --python_out=. --grpc_python_out=. user_service.proto
```

### Network Access
- **VPC Access**: Service Connect DNS (user-service-grpc:50051)
- **Or**: Port forwarding to localhost
- **Or**: Skip validation flag for local testing

## Comparison: Old vs New

| Feature | Old Scripts | New Scripts (Validated) |
|---------|------------|------------------------|
| User IDs | Sequential (1 to N) | From user-service gRPC |
| Validation | None | BatchGetUserInfo |
| Network | AWS only | VPC + gRPC endpoint |
| Fallback | N/A | --skip-validation flag |
| Use Case | Quick testing | Production-ready |

## Examples

### Generate 5K Users from Service
```bash
./generate_and_load_validated.sh \
    --grpc-endpoint user-service-grpc:50051 \
    --max-users 5000 \
    --region us-west-2
```

### Generate All Found Users
```bash
# No --max-users means "process all found users"
./generate_and_load_validated.sh \
    --grpc-endpoint user-service-grpc:50051
```

### Custom Tables
```bash
./generate_and_load_validated.sh \
    --grpc-endpoint user-service-grpc:50051 \
    --max-users 10000 \
    --followers-table my-followers \
    --following-table my-following \
    --region us-east-1
```

## Troubleshooting

### gRPC Connection Errors

**Problem:**
```
Error connecting to user-service: <_InactiveRpcError ...>
```

**Solutions:**
1. Verify you're in VPC or have port forwarding
2. Check Service Connect is enabled for user-service
3. Use `--skip-validation` for testing without gRPC

### No Users Found

**Problem:**
```
No users found in user-service
Falling back to sequential user IDs
```

**Solutions:**
1. Verify user-service has users (check RDS database)
2. Run user data generation scripts first
3. Check gRPC endpoint is correct

### Proto Import Errors

**Problem:**
```
Cannot import user_service proto files
```

**Solutions:**
1. Script auto-generates proto files
2. Or manually: `cd proto && python -m grpc_tools.protoc -I. --python_out=. --grpc_python_out=. user_service.proto`
3. Verify `grpcio-tools` is installed

## When to Use Which Script

| Scenario | Use This Script |
|----------|----------------|
| Production deployment in VPC | `generate_and_load_validated.sh` with `--grpc-endpoint` |
| Local development/testing | `generate_and_load.sh` (original, no validation) |
| CI/CD pipeline (no gRPC access) | `generate_and_load_validated.sh --skip-validation` |
| Windows environment | `load_test_data_validated.ps1` or `load_test_data.ps1` |

## See Also

- [Original Scripts (No Validation)](./README.md)
- [User Service Proto](../../../proto/user_service.proto)
- [DynamoDB Schema](../docs/DYNAMODB_SCHEMA.md)
