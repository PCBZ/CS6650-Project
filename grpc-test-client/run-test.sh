#!/bin/bash

set -e

echo "Running gRPC Test Client..."

cd "$(dirname "$0")/terraform"

# Get values from Terraform
CLUSTER_NAME=$(terraform output -raw cluster_name)
TASK_DEFINITION=$(terraform output -raw task_definition_family)
SUBNETS=$(terraform output -json ../../../terraform/public_subnet_ids 2>/dev/null || echo '[]')
SECURITY_GROUP=$(terraform output -raw security_group_id)
REGION=$(terraform output -raw aws_region 2>/dev/null || echo "us-west-2")

# Run the task
echo "Starting ECS task..."
TASK_ARN=$(aws ecs run-task \
  --cluster "$CLUSTER_NAME" \
  --task-definition "$TASK_DEFINITION" \
  --launch-type FARGATE \
  --network-configuration "awsvpcConfiguration={subnets=$(echo $SUBNETS | jq -r 'join(",")'),securityGroups=[$SECURITY_GROUP],assignPublicIp=ENABLED}" \
  --region "$REGION" \
  --query 'tasks[0].taskArn' \
  --output text)

echo "Task started: $TASK_ARN"
echo ""
echo "View logs with:"
echo "  aws logs tail /ecs/grpc-test-client --follow --region $REGION"
echo ""
echo "Or in AWS Console:"
echo "  CloudWatch > Log Groups > /ecs/grpc-test-client"
