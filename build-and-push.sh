#!/bin/bash

# Build and push Docker images to ECR
# Run this script from the project root directory

set -e  # Exit on error

AWS_REGION="us-west-2"
AWS_ACCOUNT_ID="964932215897"
ECR_REGISTRY="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"

echo "========================================="
echo "Building and Pushing Docker Images to ECR"
echo "========================================="

# Login to ECR
echo ""
echo "Step 1: Logging in to ECR..."
aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${ECR_REGISTRY}

# Build and push timeline-service
echo ""
echo "Step 2: Building timeline-service..."
cd services/timeline-service
docker build -t timeline-service:latest .
docker tag timeline-service:latest ${ECR_REGISTRY}/timeline-service:latest
echo "Pushing timeline-service to ECR..."
docker push ${ECR_REGISTRY}/timeline-service:latest
cd ../..

# Build and push user-service
echo ""
echo "Step 3: Building user-service..."
cd services/user-service
docker build -t user-service:latest .
docker tag user-service:latest ${ECR_REGISTRY}/user-service:latest
echo "Pushing user-service to ECR..."
docker push ${ECR_REGISTRY}/user-service:latest
cd ../..

# Build and push web-service
echo ""
echo "Step 4: Building web-service..."
cd web-service
docker build -t web-service:latest .
docker tag web-service:latest ${ECR_REGISTRY}/web-service:latest
echo "Pushing web-service to ECR..."
docker push ${ECR_REGISTRY}/web-service:latest
cd ..

echo ""
echo "========================================="
echo "✅ All images built and pushed successfully!"
echo "========================================="
echo ""
echo "ECR Repository URLs:"
echo "  - timeline-service: ${ECR_REGISTRY}/timeline-service:latest"
echo "  - user-service:     ${ECR_REGISTRY}/user-service:latest"
echo "  - web-service:      ${ECR_REGISTRY}/web-service:latest"
echo ""
echo "Next steps:"
echo "1. Update ECS services to use the new images"
echo "2. Run: cd terraform && ./update-ecs-services.sh"
