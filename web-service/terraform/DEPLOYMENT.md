# Web-Service Deployment Guide

## Architecture Changes

With the web-service now in Terraform, the architecture is:

```
Client → ALB → Web-Service (ECS) → User-Service (ECS) → RDS
         Port 3000            Port 8080
```

### ALB Routing Priority

The ALB routes traffic based on path patterns with priorities:
- **Priority 100**: User-Service (routes `/api/users*`)
- **Priority 200**: Web-Service (routes `/*` - catch-all)

Lower priority number = evaluated first. This ensures specific routes go to user-service, and everything else goes to web-service.

## Key Configuration Points

### 1. Service Communication

**Web-Service** needs to reach **User-Service** internally. In the `web-service/terraform/terraform.tfvars`:

```hcl
user_service_url = "http://user-service:8080"
```

This uses ECS Service Discovery. If you're not using service discovery, you'll need to:
- Use the ALB internal DNS
- Or use service discovery by adding AWS Cloud Map

### 2. Port Configuration

- **Web-Service**: Listens on port 3000 (public-facing)
- **User-Service**: Listens on port 8080 (internal)

### 3. Security Groups

- Web-service security group allows inbound on port 3000 from ALB
- Web-service can make outbound requests to user-service
- User-service security group allows inbound on port 8080 from VPC CIDR

## Deployment Steps

### Phase 1: Deploy Shared Infrastructure (if not already done)

```bash
cd /Users/zhixiaowu/CS6650-Project/terraform
terraform init
terraform plan
terraform apply
```

This creates:
- VPC and networking
- RDS PostgreSQL
- Application Load Balancer

### Phase 2: Deploy User-Service

```bash
cd /Users/zhixiaowu/CS6650-Project/services/user-service/terraform
terraform init
terraform plan
terraform apply
```

This creates:
- ECR repository for user-service
- ECS cluster and service
- Target group with ALB routing for `/api/users*`

### Phase 3: Deploy Web-Service

```bash
cd /Users/zhixiaowu/CS6650-Project/web-service/terraform
terraform init
terraform plan
terraform apply
```

This creates:
- ECR repository for web-service
- ECS cluster and service
- Target group with ALB routing for `/*` (catch-all)

### Phase 4: Verify Deployment

```bash
# Get the ALB DNS name (from any service terraform output)
cd /Users/zhixiaowu/CS6650-Project/web-service/terraform
terraform output service_endpoint

# Test the web-service
curl http://<ALB-DNS-NAME>/health

# Test user creation through web-service
curl -X POST http://<ALB-DNS-NAME>/users \
  -H "Content-Type: application/json" \
  -d '{"username": "test_user"}'

# Get users through web-service
curl http://<ALB-DNS-NAME>/users
```

## Important Notes

### Service Discovery

For web-service to communicate with user-service, you have several options:

**Option 1: ECS Service Discovery (Recommended)**
Add AWS Cloud Map service discovery to both services. Update the main.tf files to include:

```hcl
resource "aws_service_discovery_private_dns_namespace" "main" {
  name = "local"
  vpc  = data.terraform_remote_state.shared.outputs.vpc_id
}
```

**Option 2: Direct ALB Communication**
Update `user_service_url` in web-service to use the ALB internal DNS:

```hcl
user_service_url = "http://<ALB-DNS-NAME>"
```

**Option 3: Static Private IPs (Not Recommended)**
This breaks when tasks restart.

### Environment Variables

The web-service task receives:
- `USER_SERVICE_URL`: Where to find user-service
- `PORT`: Port to listen on (3000)

The user-service task receives:
- `DB_HOST`, `DB_PORT`, `DB_NAME`, `DB_USER`, `DB_PASSWORD`: Database connection
- `PORT`: Port to listen on (8080)

## Troubleshooting

### Issue: Web-service can't reach user-service

1. Check security groups:
```bash
aws ec2 describe-security-groups --filters "Name=tag:Service,Values=web_service"
aws ec2 describe-security-groups --filters "Name=tag:Service,Values=user_service"
```

2. Check if user-service is running:
```bash
aws ecs list-tasks --cluster user_service
```

3. Check logs:
```bash
aws logs tail /ecs/web_service --follow
aws logs tail /ecs/user_service --follow
```

### Issue: ALB health checks failing

1. Ensure services have `/health` endpoint
2. Check target group health:
```bash
aws elbv2 describe-target-health --target-group-arn <target-group-arn>
```

### Issue: Port conflicts in ALB routing

Make sure:
- User-service target group uses port 8080
- Web-service target group uses port 3000
- ALB listener rules have correct priorities (100 vs 200)

## Scaling Configuration

Both services have auto-scaling enabled:
- **Min capacity**: 1 task
- **Max capacity**: 10 tasks
- **CPU target**: 70%
- **Memory target**: 80%

You can modify these in `terraform.tfvars`:

```hcl
min_capacity = 2
max_capacity = 20
cpu_target_value = 60.0
```

## Cost Optimization

- **Fargate pricing**: $0.04048 per vCPU per hour + $0.004445 per GB per hour
- Current config: 256 vCPU (0.25) + 512 MB (0.5 GB) = ~$0.012 per task per hour
- With 2 services (web + user) = ~$0.024 per hour = ~$17.28 per month

To reduce costs:
1. Use fewer tasks in dev (ecs_count = 1)
2. Use smaller instance sizes (already minimal)
3. Stop services when not in use:
```bash
aws ecs update-service --cluster web_service --service web_service --desired-count 0
aws ecs update-service --cluster user_service --service user_service --desired-count 0
```

## Next Steps

1. **Set up ECS Service Discovery** for proper service-to-service communication
2. **Add HTTPS** by creating an ACM certificate and updating the ALB listener
3. **Add more services** (follower-service, post-service) following the same pattern
4. **Set up CI/CD** to automatically build and deploy on git push
5. **Add monitoring** with CloudWatch dashboards and alarms
