# gRPC Service Testing Summary

## ✅ Services Registered in CloudMap

```
user-service-grpc:50051         (srv-liemqebh4ee5vmyz)
social-graph-service-grpc:50052 (查询中)
```

## 🔧 What We Did

1. **Added Graceful Degradation** in `http_handlers.go`
   - GetFollowers and GetFollowing now continue without usernames if user-service is unavailable
   - Returns warning message instead of error

2. **Added Test Endpoint**: `/api/social-graph/test/user-service`
   - Tests gRPC connection to user-service
   - Returns connection status, response time, and user data
   - Accessible via ALB

3. **Updated Docker Build**
   - Fixed git commit issue
   - Rebuilding with `--no-cache` to ensure latest code

## 🧪 Testing Commands

### Test via HTTP Endpoint (Easiest)
```powershell
# Run test script
.\test-grpc-connection.ps1

# Or manually
$ALB_DNS = "cs6650-project-dev-alb-315577819.us-west-2.elb.amazonaws.com"
curl "http://$ALB_DNS/api/social-graph/test/user-service"
```

### Test GetFollowers (Should work now with warning)
```powershell
curl "http://$ALB_DNS/api/social-graph/913/followers"
```

**Expected Response** (if user-service unavailable):
```json
{
  "user_id": "913",
  "followers": [
    {"user_id": 123, "username": ""},
    {"user_id": 456, "username": ""}
  ],
  "total_count": 1500,
  "has_more": true,
  "next_cursor": "...",
  "warning": "User information unavailable, usernames will be empty"
}
```

### Test with grpcurl (From your local machine)

如果你想直接测试 user-service 的 gRPC：

```powershell
# Method 1: Via Private IP (需要在 VPC 内或 VPN 连接)
grpcurl -plaintext 10.0.1.183:50051 list
grpcurl -plaintext 10.0.1.183:50051 describe user_service.UserService
grpcurl -plaintext -d '{"user_ids": [1,2,3]}' 10.0.1.183:50051 user_service.UserService/BatchGetUserInfo

# Method 2: Via ECS Exec (需要先启用 ECS Exec)
# 1. 在 Terraform 中启用 execute_command
# 2. 使用 AWS Session Manager 端口转发
# 3. 然后可以连接到 localhost:50051
```

## 📊 Service Connect Status

CloudMap 中已注册的服务：
```
user-service-grpc         srv-liemqebh4ee5vmyz
post-service              srv-e6llgjxngdskvxkc
post-service-grpc         srv-6gaaf6hwluh5gs3v
social-graph-service      srv-tzrzy3ck4l72zof2
timeline-service          srv-xc3h6rfborw3bpyb
user-service              srv-54md66nw62ar22r7
```

## 🔍 Troubleshooting

### Issue: Still getting "USER_SERVICE_ERROR"

**Possible Causes:**
1. Service Connect DNS not resolving
2. Security group blocking port 50051
3. user-service not registered in CloudMap
4. Different namespace/VPC

**Solutions:**
1. Check security groups allow traffic between services
2. Verify both services in same Service Connect namespace
3. Check CloudMap service discovery instances
4. Review ECS task logs for connection errors

### Check Security Groups
```powershell
# Get social-graph-service security group
$SG_ID = aws ecs describe-services `
  --cluster social-graph-service `
  --services social-graph-service `
  --region us-west-2 `
  --query 'services[0].networkConfiguration.awsvpcConfiguration.securityGroups[0]' `
  --output text

# Check outbound rules
aws ec2 describe-security-groups `
  --group-ids $SG_ID `
  --region us-west-2 `
  --query 'SecurityGroups[0].IpPermissionsEgress'
```

### Check CloudMap Instances
```powershell
# Check if user-service-grpc has instances
aws servicediscovery discover-instances `
  --namespace-name cs6650-project-dev `
  --service-name user-service-grpc `
  --region us-west-2
```

## 📝 Next Steps

1. **Wait for build to complete** (~5 min)
2. **Push to ECR**
   ```powershell
   aws ecr get-login-password --region us-west-2 | docker login --username AWS --password-stdin 892825672262.dkr.ecr.us-west-2.amazonaws.com
   docker tag social-graph-service:latest 892825672262.dkr.ecr.us-west-2.amazonaws.com/social-graph-service:latest
   docker push 892825672262.dkr.ecr.us-west-2.amazonaws.com/social-graph-service:latest
   ```
3. **Force ECS deployment**
   ```powershell
   aws ecs update-service --cluster social-graph-service --service social-graph-service --force-new-deployment --region us-west-2
   ```
4. **Wait ~60 seconds** for new task to be healthy
5. **Test endpoints**
   ```powershell
   # Test gRPC connection
   .\test-grpc-connection.ps1
   
   # Test GetFollowers (should now work with warning if user-service unavailable)
   curl "http://$ALB_DNS/api/social-graph/913/followers"
   ```

## 🎯 Expected Results

### If user-service IS available:
- ✅ `/test/user-service` returns `status: "success"`
- ✅ `/913/followers` returns full user data with usernames
- ✅ No warnings

### If user-service NOT available:
- ⚠️ `/test/user-service` returns `status: "error"` with details
- ✅ `/913/followers` STILL WORKS but with warning
- ✅ User IDs returned, usernames empty
- ⚠️ Response includes: `"warning": "User information unavailable"`
