# Update ECS services to use the new Docker images from ECR
# Run this script from the terraform directory

$ErrorActionPreference = "Stop"

$AWS_REGION = "us-west-2"
$AWS_ACCOUNT_ID = "892825672262"
$ECR_REGISTRY = "$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com"

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "Updating ECS Services with New Images" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan

# Function to update ECS service
function Update-ECSService {
    param(
        [string]$ClusterName,
        [string]$ServiceName,
        [string]$TaskDefName,
        [string]$ImageName
    )
    
    Write-Host ""
    Write-Host "Updating $ServiceName..." -ForegroundColor Yellow
    
    try {
        # Get current task definition
        $taskDefJson = aws ecs describe-task-definition --task-definition $TaskDefName --region $AWS_REGION --query 'taskDefinition' --output json | ConvertFrom-Json
        
        # Update image in container definition
        $taskDefJson.containerDefinitions[0].image = "$ECR_REGISTRY/${ImageName}:latest"
        
        # Remove fields that shouldn't be in register-task-definition
        $taskDefJson.PSObject.Properties.Remove('taskDefinitionArn')
        $taskDefJson.PSObject.Properties.Remove('revision')
        $taskDefJson.PSObject.Properties.Remove('status')
        $taskDefJson.PSObject.Properties.Remove('requiresAttributes')
        $taskDefJson.PSObject.Properties.Remove('compatibilities')
        $taskDefJson.PSObject.Properties.Remove('registeredAt')
        $taskDefJson.PSObject.Properties.Remove('registeredBy')
        
        # Register new task definition
        $newTaskDefJson = $taskDefJson | ConvertTo-Json -Depth 10 -Compress
        aws ecs register-task-definition --region $AWS_REGION --cli-input-json $newTaskDefJson | Out-Null
        
        # Update service with new task definition
        aws ecs update-service --cluster $ClusterName --service $ServiceName --task-definition $TaskDefName --region $AWS_REGION --force-new-deployment | Out-Null
        
        Write-Host "✅ $ServiceName updated" -ForegroundColor Green
    }
    catch {
        Write-Host "❌ Failed to update $ServiceName : $_" -ForegroundColor Red
        throw
    }
}

# Update social-graph-service
Update-ECSService -ClusterName "social-graph" -ServiceName "social-graph" -TaskDefName "social-graph" -ImageName "social-graph-service"

# Update user-service
Update-ECSService -ClusterName "user-service" -ServiceName "user-service" -TaskDefName "user-service" -ImageName "user-service"

# Update web-service
Update-ECSService -ClusterName "web-service" -ServiceName "web-service" -TaskDefName "web-service" -ImageName "web-service"

Write-Host ""
Write-Host "=========================================" -ForegroundColor Green
Write-Host "✅ All ECS services updated successfully!" -ForegroundColor Green
Write-Host "=========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Monitor deployment status:" -ForegroundColor Cyan
Write-Host "  aws ecs describe-services --cluster social-graph --services social-graph --region $AWS_REGION" -ForegroundColor White
Write-Host "  aws ecs describe-services --cluster user-service --services user-service --region $AWS_REGION" -ForegroundColor White
Write-Host "  aws ecs describe-services --cluster web-service --services web-service --region $AWS_REGION" -ForegroundColor White
Write-Host ""
Write-Host "Or use AWS Console:" -ForegroundColor Cyan
Write-Host "  https://us-west-2.console.aws.amazon.com/ecs/v2/clusters" -ForegroundColor White
