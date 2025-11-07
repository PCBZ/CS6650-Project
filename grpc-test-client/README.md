# gRPC Test Client

This is a test client for verifying gRPC connectivity to the user-service running in AWS ECS.

## Why Deploy Inside AWS?

gRPC communication is configured for **internal service-to-service communication only** via AWS ECS Service Connect. This means:

- ✅ Services can communicate via Service Connect DNS names (e.g., `user-service-grpc:50051`)
- ❌ External access to gRPC endpoints is not available (no public endpoint)
- 🔒 This is a security best practice for microservices

## Architecture

```
┌─────────────────────────────────────────┐
│  AWS ECS (Service Connect Network)      │
│                                          │
│  ┌──────────────┐    gRPC              │
│  │ gRPC Test    ├──────────────┐        │
│  │ Client       │              │        │
│  └──────────────┘              ▼        │
│                        ┌────────────┐   │
│                        │ User       │   │
│                        │ Service    │   │
│                        │ :50051     │   │
│                        └────────────┘   │
└─────────────────────────────────────────┘
```

## Deployment

### Prerequisites
- AWS CLI configured
- Docker installed
- Terraform installed
- Existing infrastructure deployed (run terraform in `/terraform` first)

### Deploy with Terraform (Recommended)

```bash
cd grpc-test-client/terraform
terraform init
terraform apply
```

This will:
1. Create ECR repository
2. Create ECS cluster and task definition
3. **Automatically build and push Docker image to ECR**
4. Set up CloudWatch Logs

No shell scripts needed! Terraform handles everything.

## Running the Test

### Option 1: Use the helper script

```bash
./run-test.sh
```

### Option 2: Use Terraform output

```bash
cd terraform
terraform output -raw run_task_command | bash
```

### Option 3: Manual AWS CLI

```bash
aws ecs run-task \
  --cluster grpc-test-client \
  --task-definition grpc-test-client \
  --launch-type FARGATE \
  --network-configuration "awsvpcConfiguration={subnets=[subnet-xxx],securityGroups=[sg-xxx],assignPublicIp=ENABLED}" \
  --region us-west-2
```

## Viewing Results

Check CloudWatch Logs to see the test results:

```bash
# View recent logs
aws logs tail /ecs/grpc-test-client --follow --region us-west-2
```

Or go to AWS Console:
- Navigate to CloudWatch > Log Groups
- Open `/ecs/grpc-test-client`
- View the latest log stream

## Expected Output

Successful test output should look like:

```
Connecting to gRPC server at user-service-grpc:50051...
✓ Successfully connected to gRPC server

Testing BatchGetUserInfo with user IDs: [1 2 3 4 5]

Sending BatchGetUserInfo request...

--- Response ---
Found 5 users:
  - User ID 1: user1
  - User ID 2: user2
  - User ID 3: user3
  - User ID 4: user4
  - User ID 5: user5
----------------

✓ gRPC test completed successfully!
```

## Customizing the Test

To test with different user IDs, update the Dockerfile CMD:

```dockerfile
CMD ["-server", "user-service-grpc:50051", "-users", "1,2,3,4,5,100,200"]
```

Then rebuild and redeploy:

```bash
cd terraform
terraform apply  # Will automatically rebuild and push new image
```

## Cleanup

To remove the test client infrastructure:

```bash
cd terraform
terraform destroy
```

## Troubleshooting

### Connection Refused
- Verify user-service is running: `aws ecs list-tasks --cluster user-service`
- Check Service Connect configuration is enabled on both services

### User IDs Not Found
- The test queries user IDs 1-5 by default
- Make sure you have test data in the database
- Run the data generation scripts in `services/user-service/scripts/`

### No Logs Appearing
- Wait 30-60 seconds for the task to start and complete
- Check task status: `aws ecs describe-tasks --cluster grpc-test-client --tasks <task-id>`

### Docker Build Fails
- Ensure Docker is running
- Check that you have AWS credentials configured
- Verify you're in the correct directory
