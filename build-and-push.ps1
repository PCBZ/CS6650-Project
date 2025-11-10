# Build and push Docker images to ECR
# Run this script from the project root directory

$ErrorActionPreference = "Stop"

$AWS_REGION = "us-west-2"
$AWS_ACCOUNT_ID = "892825672262"
$ECR_REGISTRY = "$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com"

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "Building and Pushing Docker Images to ECR" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan

# Login to ECR
Write-Host ""
Write-Host "Step 1: Logging in to ECR..." -ForegroundColor Yellow
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $ECR_REGISTRY
if ($LASTEXITCODE -ne 0) {
    Write-Host "Failed to login to ECR" -ForegroundColor Red
    exit 1
}

# Build and push social-graph-service
Write-Host ""
Write-Host "Step 2: Building social-graph-service..." -ForegroundColor Yellow
Set-Location services/social-graph-services
docker build -t social-graph-service:latest .
if ($LASTEXITCODE -ne 0) {
    Write-Host "Failed to build social-graph-service" -ForegroundColor Red
    exit 1
}
docker tag social-graph-service:latest "$ECR_REGISTRY/social-graph-service:latest"
Write-Host "Pushing social-graph-service to ECR..." -ForegroundColor Yellow
docker push "$ECR_REGISTRY/social-graph-service:latest"
if ($LASTEXITCODE -ne 0) {
    Write-Host "Failed to push social-graph-service" -ForegroundColor Red
    exit 1
}
Set-Location ../..

# Build and push user-service
Write-Host ""
Write-Host "Step 3: Building user-service..." -ForegroundColor Yellow
Set-Location services/user-service
docker build -t user-service:latest .
if ($LASTEXITCODE -ne 0) {
    Write-Host "Failed to build user-service" -ForegroundColor Red
    exit 1
}
docker tag user-service:latest "$ECR_REGISTRY/user-service:latest"
Write-Host "Pushing user-service to ECR..." -ForegroundColor Yellow
docker push "$ECR_REGISTRY/user-service:latest"
if ($LASTEXITCODE -ne 0) {
    Write-Host "Failed to push user-service" -ForegroundColor Red
    exit 1
}
Set-Location ../..

# Build and push web-service
Write-Host ""
Write-Host "Step 4: Building web-service..." -ForegroundColor Yellow
Set-Location web-service
docker build -t web-service:latest .
if ($LASTEXITCODE -ne 0) {
    Write-Host "Failed to build web-service" -ForegroundColor Red
    exit 1
}
docker tag web-service:latest "$ECR_REGISTRY/web-service:latest"
Write-Host "Pushing web-service to ECR..." -ForegroundColor Yellow
docker push "$ECR_REGISTRY/web-service:latest"
if ($LASTEXITCODE -ne 0) {
    Write-Host "Failed to push web-service" -ForegroundColor Red
    exit 1
}
Set-Location ..

Write-Host ""
Write-Host "=========================================" -ForegroundColor Green
Write-Host "✅ All images built and pushed successfully!" -ForegroundColor Green
Write-Host "=========================================" -ForegroundColor Green
Write-Host ""
Write-Host "ECR Repository URLs:" -ForegroundColor Cyan
Write-Host "  - social-graph-service: $ECR_REGISTRY/social-graph-service:latest" -ForegroundColor White
Write-Host "  - user-service:         $ECR_REGISTRY/user-service:latest" -ForegroundColor White
Write-Host "  - web-service:          $ECR_REGISTRY/web-service:latest" -ForegroundColor White
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "1. Update ECS services to use the new images" -ForegroundColor White
Write-Host "2. Run: cd terraform; .\update-ecs-services.ps1" -ForegroundColor White
