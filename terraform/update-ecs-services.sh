#!/bin/bash

# Update ECS services to use the new Docker images from ECR
# Run this script from the terraform directory

set -e

AWS_REGION="us-west-2"
AWS_ACCOUNT_ID="964932215897"
ECR_REGISTRY="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"

echo "========================================="
echo "Updating ECS Services with New Images"
echo "========================================="

# Update timeline-service
echo ""
echo "Updating timeline-service..."
TIMELINE_TASK_DEF=$(aws ecs describe-task-definition --task-definition timeline-service --region ${AWS_REGION} --query 'taskDefinition' --output json)
TIMELINE_NEW_TASK_DEF=$(echo $TIMELINE_TASK_DEF | jq --arg IMAGE "${ECR_REGISTRY}/timeline-service:latest" '.containerDefinitions[0].image = $IMAGE | del(.taskDefinitionArn, .revision, .status, .requiresAttributes, .compatibilities, .registeredAt, .registeredBy)')
aws ecs register-task-definition --region ${AWS_REGION} --cli-input-json "$TIMELINE_NEW_TASK_DEF" > /dev/null
aws ecs update-service --cluster timeline-service --service timeline-service --task-definition timeline-service --region ${AWS_REGION} --force-new-deployment > /dev/null
echo "✅ timeline-service updated"

# Update user-service
echo ""
echo "Updating user-service..."
USER_TASK_DEF=$(aws ecs describe-task-definition --task-definition user-service --region ${AWS_REGION} --query 'taskDefinition' --output json)
USER_NEW_TASK_DEF=$(echo $USER_TASK_DEF | jq --arg IMAGE "${ECR_REGISTRY}/user-service:latest" '.containerDefinitions[0].image = $IMAGE | del(.taskDefinitionArn, .revision, .status, .requiresAttributes, .compatibilities, .registeredAt, .registeredBy)')
aws ecs register-task-definition --region ${AWS_REGION} --cli-input-json "$USER_NEW_TASK_DEF" > /dev/null
aws ecs update-service --cluster user-service --service user-service --task-definition user-service --region ${AWS_REGION} --force-new-deployment > /dev/null
echo "✅ user-service updated"

# Update web-service
echo ""
echo "Updating web-service..."
WEB_TASK_DEF=$(aws ecs describe-task-definition --task-definition web-service --region ${AWS_REGION} --query 'taskDefinition' --output json)
WEB_NEW_TASK_DEF=$(echo $WEB_TASK_DEF | jq --arg IMAGE "${ECR_REGISTRY}/web-service:latest" '.containerDefinitions[0].image = $IMAGE | del(.taskDefinitionArn, .revision, .status, .requiresAttributes, .compatibilities, .registeredAt, .registeredBy)')
aws ecs register-task-definition --region ${AWS_REGION} --cli-input-json "$WEB_NEW_TASK_DEF" > /dev/null
aws ecs update-service --cluster web-service --service web-service --task-definition web-service --region ${AWS_REGION} --force-new-deployment > /dev/null
echo "✅ web-service updated"

echo ""
echo "========================================="
echo "✅ All ECS services updated successfully!"
echo "========================================="
echo ""
echo "Monitor deployment status:"
echo "  aws ecs describe-services --cluster timeline-service --services timeline-service --region ${AWS_REGION}"
echo "  aws ecs describe-services --cluster user-service --services user-service --region ${AWS_REGION}"
echo "  aws ecs describe-services --cluster web-service --services web-service --region ${AWS_REGION}"
