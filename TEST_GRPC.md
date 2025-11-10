# gRPC Service Testing Guide

## 📋 Service Information

### User Service (user-service-grpc)
- **Internal DNS**: `user-service-grpc:50051` (Service Connect)
- **Private IP**: `10.0.1.183`
- **CloudMap Service ID**: `srv-liemqebh4ee5vmyz`
- **Cluster**: `user-service`
- **Task ID**: `2a331ce3432744c7b1f666efd522874b`

### Social Graph Service (social-graph-service-grpc)
- **Internal DNS**: `social-graph-service-grpc:50052` (Service Connect)
- **Private IP**: `10.0.1.185`
- **CloudMap Service ID**: (查询中)
- **Cluster**: `social-graph-service`
- **Task ID**: `fcad50becb7747c481631d2935734ad8`

---

## 🧪 Testing with grpcurl

### 1. Test from Local Machine (via Port Forwarding)

#### Option A: Use ECS Exec to Port Forward
```powershell
# 首先启用 ECS Exec（需要更新 Terraform）
# 然后使用 AWS Session Manager 端口转发

# 转发 user-service gRPC 端口
aws ssm start-session `
  --target ecs:user-service_2a331ce3432744c7b1f666efd522874b_... `
  --document-name AWS-StartPortForwardingSession `
  --parameters "portNumber=50051,localPortNumber=50051" `
  --region us-west-2
```

#### Option B: Direct IP Test (如果安全组允许)
```powershell
# 测试 user-service gRPC (需要先配置安全组允许 50051 端口)
grpcurl -plaintext 10.0.1.183:50051 list

# 测试 social-graph-service gRPC
grpcurl -plaintext 10.0.1.185:50052 list
```

### 2. Test from Within VPC (推荐)

#### 创建测试脚本在 ECS 任务中运行

**test-grpc-connection.sh**:
```bash
#!/bin/bash

echo "========================================="
echo "Testing gRPC Service Connectivity"
echo "========================================="

# Test 1: DNS Resolution
echo ""
echo "1. Testing DNS Resolution..."
echo "   user-service-grpc:"
getent hosts user-service-grpc || echo "   ❌ DNS resolution failed"

echo "   social-graph-service-grpc:"
getent hosts social-graph-service-grpc || echo "   ❌ DNS resolution failed"

# Test 2: Port Connectivity
echo ""
echo "2. Testing Port Connectivity..."
echo "   user-service-grpc:50051"
nc -zv user-service-grpc 50051 2>&1

echo "   social-graph-service-grpc:50052"
nc -zv social-graph-service-grpc 50052 2>&1

# Test 3: gRPC Health Check (if grpcurl is available)
if command -v grpcurl &> /dev/null; then
    echo ""
    echo "3. Testing gRPC Services..."
    
    echo "   user-service-grpc - List services:"
    grpcurl -plaintext user-service-grpc:50051 list
    
    echo ""
    echo "   user-service-grpc - Describe UserService:"
    grpcurl -plaintext user-service-grpc:50051 describe user_service.UserService
    
    echo ""
    echo "   social-graph-service-grpc - List services:"
    grpcurl -plaintext social-graph-service-grpc:50052 list
fi

echo ""
echo "========================================="
echo "Test Complete"
echo "========================================="
```

---

## 🔍 grpcurl Commands Reference

### User Service Tests

#### 1. List all services
```powershell
grpcurl -plaintext user-service-grpc:50051 list
```

**Expected Output:**
```
user_service.UserService
grpc.reflection.v1alpha.ServerReflection
```

#### 2. Describe UserService
```powershell
grpcurl -plaintext user-service-grpc:50051 describe user_service.UserService
```

#### 3. List UserService methods
```powershell
grpcurl -plaintext user-service-grpc:50051 list user_service.UserService
```

**Expected Output:**
```
user_service.UserService.BatchGetUserInfo
user_service.UserService.CreateUser
user_service.UserService.GetUserInfo
```

#### 4. Test BatchGetUserInfo
```powershell
# Using proto file
grpcurl -plaintext `
  -proto d:\YI` XU\Documents\CSA\CS6650\CS6650-Project\CS6650-Project\proto\user_service.proto `
  -d '{"user_ids": [1, 2, 3, 100, 913]}' `
  user-service-grpc:50051 user_service.UserService/BatchGetUserInfo

# Without proto (using reflection)
grpcurl -plaintext `
  -d '{"user_ids": [1, 2, 3, 100, 913]}' `
  user-service-grpc:50051 user_service.UserService/BatchGetUserInfo
```

**Expected Output:**
```json
{
  "users": {
    "1": {
      "user_id": "1",
      "username": "user_1"
    },
    "2": {
      "user_id": "2",
      "username": "user_2"
    }
  },
  "not_found": []
}
```

#### 5. Test GetUserInfo (single user)
```powershell
grpcurl -plaintext `
  -d '{"user_id": 913}' `
  user-service-grpc:50051 user_service.UserService/GetUserInfo
```

---

## 🧪 Testing from social-graph-service Container

### Method 1: Execute command in running container

```powershell
# Install grpcurl in the container (Alpine)
aws ecs execute-command `
  --cluster social-graph-service `
  --task fcad50becb7747c481631d2935734ad8 `
  --container social-graph-service `
  --command "/bin/sh" `
  --interactive `
  --region us-west-2

# Then inside container:
# Test DNS resolution
nslookup user-service-grpc
ping -c 3 user-service-grpc

# Test port connectivity
nc -zv user-service-grpc 50051

# If you have curl/telnet
telnet user-service-grpc 50051
```

### Method 2: Add test endpoint to social-graph-service

在 `http_handlers.go` 中添加测试端点：

```go
// TestUserServiceConnection tests the connection to user-service gRPC
func (h *HTTPHandler) TestUserServiceConnection(c *gin.Context) {
	ctx, cancel := context.WithTimeout(c.Request.Context(), 10*time.Second)
	defer cancel()

	// Test with a simple BatchGetUserInfo call
	testUserIDs := []int64{1, 2, 3}
	users, notFound, err := h.userServiceClient.BatchGetUserInfo(ctx, testUserIDs)

	if err != nil {
		c.JSON(http.StatusOK, gin.H{
			"status":  "error",
			"error":   err.Error(),
			"message": "Failed to connect to user-service gRPC",
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"status":    "success",
		"message":   "Successfully connected to user-service gRPC",
		"tested_ids": testUserIDs,
		"found":     len(users),
		"not_found": len(notFound),
		"users":     users,
	})
}
```

然后在 `main.go` 中注册路由：
```go
router.GET("/api/social-graph/test/user-service", httpHandler.TestUserServiceConnection)
```

---

## 🔧 Troubleshooting

### Issue 1: DNS Resolution Fails

```powershell
# Check Service Connect configuration
aws ecs describe-services `
  --cluster user-service `
  --services user-service `
  --region us-west-2 `
  --query 'services[0].serviceConnectConfiguration'

# Check CloudMap namespace
aws servicediscovery list-services `
  --region us-west-2 `
  --filters Name=NAMESPACE_ID,Values=ns-cmjnkbkyauz2echc `
  --query 'Services[*].[Name,Id]'
```

**Solution**: Ensure both services are in the same Service Connect namespace.

### Issue 2: Connection Timeout

```powershell
# Check security groups
aws ec2 describe-security-groups `
  --region us-west-2 `
  --filters "Name=tag:Name,Values=*social-graph*" `
  --query 'SecurityGroups[*].[GroupId,GroupName,VpcId]'

# Check if port 50051 is allowed
aws ec2 describe-security-groups `
  --group-ids sg-xxxxx `
  --region us-west-2 `
  --query 'SecurityGroups[0].IpPermissions[?ToPort==`50051`]'
```

**Solution**: Update security group to allow port 50051 from social-graph-service security group.

### Issue 3: Service Not Registered in CloudMap

```powershell
# Check service registration
aws servicediscovery discover-instances `
  --namespace-name cs6650-project-dev `
  --service-name user-service-grpc `
  --region us-west-2

# Check service instances
aws servicediscovery list-instances `
  --service-id srv-liemqebh4ee5vmyz `
  --region us-west-2
```

**Solution**: Verify Service Connect configuration in Terraform and redeploy.

---

## 📊 Quick Test Commands

```powershell
# 1. Check if services are registered
aws servicediscovery list-services `
  --region us-west-2 `
  --filters Name=NAMESPACE_ID,Values=ns-cmjnkbkyauz2echc `
  --query 'Services[?contains(Name, `grpc`)].Name'

# 2. Get service instances
aws servicediscovery discover-instances `
  --namespace-name cs6650-project-dev `
  --service-name user-service-grpc `
  --region us-west-2

# 3. Test from local (if port forwarding setup)
grpcurl -plaintext localhost:50051 list

# 4. Test via HTTP endpoint (after adding test endpoint)
curl "http://cs6650-project-dev-alb-315577819.us-west-2.elb.amazonaws.com/api/social-graph/test/user-service"
```

---

## 🚀 Recommended Testing Workflow

1. **Verify Service Registration**
   ```powershell
   aws servicediscovery discover-instances `
     --namespace-name cs6650-project-dev `
     --service-name user-service-grpc `
     --region us-west-2
   ```

2. **Add HTTP Test Endpoint** (easiest for external testing)
   - Add `TestUserServiceConnection` handler to social-graph-service
   - Deploy and test via ALB
   - Check logs for connection errors

3. **Use ECS Exec** (for direct testing)
   ```powershell
   # Enable ECS Exec in Terraform first
   aws ecs execute-command `
     --cluster social-graph-service `
     --task fcad50becb7747c481631d2935734ad8 `
     --container social-graph-service `
     --command "/bin/sh" `
     --interactive
   ```

4. **Check Security Groups**
   - Ensure social-graph-service SG can reach user-service SG on port 50051
   - Update inbound rules if needed

5. **Monitor Logs**
   ```powershell
   aws logs tail "/ecs/social-graph-service" `
     --region us-west-2 `
     --follow `
     --format short
   ```
