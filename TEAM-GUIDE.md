# What's Shared vs What You Add

## 🌐 Already Created (Shared Infrastructure)

**You DON'T need to create these - they already exist:**

- **VPC & Subnets** - Network is ready
- **Application Load Balancer** - ALB is deployed  
- **RDS PostgreSQL Server** - Database server is running
- **Security Groups** - Base network security is configured

## 🏠 What You Need to Add (Your Service)

**When creating a new service, you must add:**

### 1. Target Group for Your Service
```hcl
# In your services/{service-name}/terraform/main.tf
resource "aws_lb_target_group" "service" {
  name     = "${var.service_name}-tg"
  vpc_id   = data.terraform_remote_state.shared.outputs.vpc_id
  # ...
}
```

### 2. ALB Listener Rule for Your Path
```hcl
# In your services/{service-name}/terraform/main.tf
resource "aws_lb_listener_rule" "service" {
  listener_arn = data.terraform_remote_state.shared.outputs.alb_listener_arn
  priority     = var.alb_priority  # Choose unique: 100, 200, 300...
  
  condition {
    path_pattern { values = ["/api/your-service/*"] }
  }
  
  action {
    type = "forward"
    target_group_arn = aws_lb_target_group.service.arn
  }
}
```

### 3. Your ECS Service & Containers
```hcl
# Your application containers, security groups, etc.
```

## 🎯 Coordination Needed

**ALB Priority** - Pick unique number:
- user-service: 100
- your-service: 200 (pick next available)

**Path Pattern** - Use consistent format:
- `/api/users/*` → user-service  
- `/api/your-service/*` → your-service

That's it! Copy the user-service structure and update these values.