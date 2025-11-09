#!/bin/bash
# Build and deploy social-graph-service Docker image to ECR

set -e

# Configuration
AWS_REGION="us-west-2"
AWS_ACCOUNT_ID="892825672262"
ECR_REPOSITORY="social-graph-service"
SERVICE_DIR="services/social-graph-services"
IMAGE_TAG="latest"

echo "========================================="
echo "Building and Deploying Social Graph Service"
echo "========================================="
echo ""

# Step 1: Login to ECR
echo "1. Logging in to ECR..."
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com

if [ $? -eq 0 ]; then
    echo "✓ ECR login successful"
else
    echo "✗ ECR login failed"
    exit 1
fi

echo ""

# Step 2: Build Docker image
echo "2. Building Docker image..."
cd $SERVICE_DIR

docker build -t ${ECR_REPOSITORY}:${IMAGE_TAG} .

if [ $? -eq 0 ]; then
    echo "✓ Docker image built successfully"
else
    echo "✗ Docker build failed"
    exit 1
fi

echo ""

# Step 3: Tag image for ECR
echo "3. Tagging image for ECR..."
docker tag ${ECR_REPOSITORY}:${IMAGE_TAG} ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPOSITORY}:${IMAGE_TAG}

echo "✓ Image tagged"
echo ""

# Step 4: Push to ECR
echo "4. Pushing image to ECR..."
docker push ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPOSITORY}:${IMAGE_TAG}

if [ $? -eq 0 ]; then
    echo "✓ Image pushed successfully"
else
    echo "✗ Image push failed"
    exit 1
fi

echo ""

# Step 5: Force new deployment
echo "5. Forcing ECS service update..."
cd ../..
aws ecs update-service \
    --cluster social-graph-service \
    --service social-graph-service \
    --force-new-deployment \
    --region $AWS_REGION \
    --query 'service.{ServiceName:serviceName,Status:status,DesiredCount:desiredCount}' \
    --output table

if [ $? -eq 0 ]; then
    echo "✓ Service update triggered"
else
    echo "✗ Service update failed"
    exit 1
fi

echo ""
echo "========================================="
echo "Deployment Complete!"
echo "========================================="
echo ""
echo "Next steps:"
echo "1. Wait 2-3 minutes for tasks to start"
echo "2. Check service status:"
echo "   aws ecs describe-services --cluster social-graph-service --services social-graph-service --region us-west-2"
echo ""
echo "3. View logs:"
echo "   aws logs tail /ecs/social-graph-service --follow --region us-west-2"
echo ""
echo "4. Test the service:"
echo "   curl http://cs6650-project-dev-alb-1139764678.us-west-2.elb.amazonaws.com/api/health"
echo ""
