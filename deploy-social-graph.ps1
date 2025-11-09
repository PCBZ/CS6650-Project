# Build and deploy social-graph-service Docker image to ECR

$ErrorActionPreference = "Stop"

# Configuration
$AWS_REGION = "us-west-2"
$AWS_ACCOUNT_ID = "892825672262"
$ECR_REPOSITORY = "social-graph-service"
$SERVICE_DIR = "services\social-graph-services"
$IMAGE_TAG = "latest"

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "Building and Deploying Social Graph Service" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

# Step 1: Login to ECR
Write-Host "1. Logging in to ECR..." -ForegroundColor Yellow
try {
    $loginPassword = aws ecr get-login-password --region $AWS_REGION
    $loginPassword | docker login --username AWS --password-stdin "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com" 2>&1 | Out-Null
    Write-Host "   ✓ ECR login successful" -ForegroundColor Green
} catch {
    Write-Host "   ✗ ECR login failed: $_" -ForegroundColor Red
    exit 1
}

Write-Host ""

# Step 2: Build Docker image (from project root, using Dockerfile in service dir)
Write-Host "2. Building Docker image from project root..." -ForegroundColor Yellow

try {
    # Build from root directory, but use Dockerfile from service directory
    docker build -f "$SERVICE_DIR\Dockerfile" -t "${ECR_REPOSITORY}:${IMAGE_TAG}" .
    if ($LASTEXITCODE -eq 0) {
        Write-Host "   ✓ Docker image built successfully" -ForegroundColor Green
    } else {
        throw "Docker build failed with exit code $LASTEXITCODE"
    }
} catch {
    Write-Host "   ✗ Docker build failed: $_" -ForegroundColor Red
    exit 1
}

Write-Host ""

# Step 3: Tag image for ECR
Write-Host "3. Tagging image for ECR..." -ForegroundColor Yellow
docker tag "${ECR_REPOSITORY}:${IMAGE_TAG}" "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPOSITORY}:${IMAGE_TAG}"
Write-Host "   ✓ Image tagged" -ForegroundColor Green
Write-Host ""

# Step 4: Push to ECR
Write-Host "4. Pushing image to ECR..." -ForegroundColor Yellow
try {
    docker push "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPOSITORY}:${IMAGE_TAG}"
    if ($LASTEXITCODE -eq 0) {
        Write-Host "   ✓ Image pushed successfully" -ForegroundColor Green
    } else {
        throw "Docker push failed with exit code $LASTEXITCODE"
    }
} catch {
    Write-Host "   ✗ Image push failed: $_" -ForegroundColor Red
    exit 1
}
Write-Host ""

# Step 5: Force new deployment
Write-Host "5. Forcing ECS service update..." -ForegroundColor Yellow
try {
    aws ecs update-service `
        --cluster social-graph-service `
        --service social-graph-service `
        --force-new-deployment `
        --region $AWS_REGION `
        --query 'service.{ServiceName:serviceName,Status:status,DesiredCount:desiredCount}' `
        --output table
    
    Write-Host "   ✓ Service update triggered" -ForegroundColor Green
} catch {
    Write-Host "   ✗ Service update failed: $_" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "Deployment Complete!" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Next steps:" -ForegroundColor White
Write-Host "1. Wait 2-3 minutes for tasks to start" -ForegroundColor Gray
Write-Host "2. Check service status:" -ForegroundColor Gray
Write-Host "   aws ecs describe-services --cluster social-graph-service --services social-graph-service --region us-west-2" -ForegroundColor DarkGray
Write-Host ""
Write-Host "3. View logs:" -ForegroundColor Gray
Write-Host "   aws logs tail /ecs/social-graph-service --follow --region us-west-2" -ForegroundColor DarkGray
Write-Host ""
Write-Host "4. Test the service:" -ForegroundColor Gray
Write-Host "   Invoke-WebRequest -Uri 'http://cs6650-project-dev-alb-2003105151.us-west-2.elb.amazonaws.com/api/health'" -ForegroundColor DarkGray
Write-Host ""
