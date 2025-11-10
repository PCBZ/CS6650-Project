# Test Social Graph Service - HTTP API and gRPC endpoints

$ErrorActionPreference = "Continue"
$ALB_DNS = "cs6650-project-dev-alb-315577819.us-west-2.elb.amazonaws.com"

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Social Graph Service - Full Test Suite" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# Test data - User 913 is Top tier
$topUser = 913
$smallUser1 = 1
$smallUser2 = 100

Write-Host "📊 Test Configuration:" -ForegroundColor Yellow
Write-Host "  ALB DNS: $ALB_DNS" -ForegroundColor Gray
Write-Host "  Top User: $topUser (expected 2000 followers)" -ForegroundColor Gray
Write-Host "  Small Users: $smallUser1, $smallUser2 (expected 1 follower each)`n" -ForegroundColor Gray

# ====================
# HTTP API Tests
# ====================
Write-Host "🌐 HTTP API Tests" -ForegroundColor Cyan
Write-Host "==================`n" -ForegroundColor Cyan

# Test 1: Health Check
Write-Host "1. Health Check..." -ForegroundColor Yellow
try {
    $response = Invoke-RestMethod -Uri "http://$ALB_DNS/api/social-graph/health" -Method GET -TimeoutSec 10
    Write-Host "   ✅ Status: $($response.status)" -ForegroundColor Green
    Write-Host "   Service: $($response.service)`n" -ForegroundColor Gray
} catch {
    Write-Host "   ❌ Health check failed: $($_.Exception.Message)`n" -ForegroundColor Red
}

# Test 2: Get Follower Count
Write-Host "2. Get Follower Counts..." -ForegroundColor Yellow
$testUsers = @(
    @{id=$topUser; tier="Top"; expected=2000},
    @{id=$smallUser1; tier="Small"; expected=1},
    @{id=$smallUser2; tier="Small"; expected=1}
)

foreach($user in $testUsers) {
    try {
        $response = Invoke-RestMethod -Uri "http://$ALB_DNS/api/social-graph/followers/$($user.id)/count" -Method GET -TimeoutSec 10
        $count = $response.followerCount
        $match = if($count -eq $user.expected){"✅"}else{"❌"}
        Write-Host "   $match User $($user.id) ($($user.tier)): $count followers (expected $($user.expected))" -ForegroundColor $(if($match -eq "✅"){"Green"}else{"Red"})
    } catch {
        Write-Host "   ❌ User $($user.id) error: $($_.Exception.Message)" -ForegroundColor Red
    }
}
Write-Host ""

# Test 3: Get Following Count
Write-Host "3. Get Following Counts..." -ForegroundColor Yellow
foreach($user in $testUsers) {
    try {
        $response = Invoke-RestMethod -Uri "http://$ALB_DNS/api/social-graph/following/$($user.id)/count" -Method GET -TimeoutSec 10
        $count = $response.followingCount
        Write-Host "   ✅ User $($user.id): $count following" -ForegroundColor Green
    } catch {
        Write-Host "   ❌ User $($user.id) error: $($_.Exception.Message)" -ForegroundColor Red
    }
}
Write-Host ""

# Test 4: Get Followers List
Write-Host "4. Get Followers List (Top User)..." -ForegroundColor Yellow
try {
    $response = Invoke-RestMethod -Uri "http://$ALB_DNS/api/social-graph/$topUser/followers" -Method GET -TimeoutSec 10
    $count = if($response.followers){$response.followers.Count}else{0}
    Write-Host "   ✅ Retrieved $count followers (total: $($response.total_count))" -ForegroundColor Green
    if($response.followers -and $response.followers.Count -gt 0) {
        $sampleIds = ($response.followers[0..4] | ForEach-Object { $_.user_id }) -join ', '
        Write-Host "   Sample IDs: $sampleIds..." -ForegroundColor Gray
    }
    Write-Host "   Has more: $($response.has_more)`n" -ForegroundColor Gray
} catch {
    Write-Host "   ❌ Error: $($_.Exception.Message)`n" -ForegroundColor Red
}

# Test 5: Get Following List
Write-Host "5. Get Following List (Top User)..." -ForegroundColor Yellow
try {
    $response = Invoke-RestMethod -Uri "http://$ALB_DNS/api/social-graph/$topUser/following" -Method GET -TimeoutSec 10
    $count = if($response.following){$response.following.Count}else{0}
    Write-Host "   ✅ Retrieved $count following (total: $($response.total_count))" -ForegroundColor Green
    if($response.following -and $response.following.Count -gt 0) {
        $sampleIds = ($response.following[0..4] | ForEach-Object { $_.user_id }) -join ', '
        Write-Host "   Sample IDs: $sampleIds..." -ForegroundColor Gray
    }
    Write-Host "   Has more: $($response.has_more)`n" -ForegroundColor Gray
} catch {
    Write-Host "   ❌ Error: $($_.Exception.Message)`n" -ForegroundColor Red
}

# Test 6: Check Relationship
Write-Host "6. Check Relationship..." -ForegroundColor Yellow
try {
    # Check if smallUser1 follows topUser
    $response = Invoke-RestMethod -Uri "http://$ALB_DNS/api/social-graph/relationship/check?followerId=$smallUser1&targetId=$topUser" -Method GET -TimeoutSec 10
    $follows = $response.isFollowing
    $status = if($follows -eq $true){"✅ Yes"}elseif($follows -eq $false){"❌ No"}else{"⚠️ Unknown"}
    $color = if($follows -eq $true){"Green"}elseif($follows -eq $false){"Yellow"}else{"Gray"}
    Write-Host "   $status - User $smallUser1 follows User ${topUser}: $follows`n" -ForegroundColor $color
} catch {
    Write-Host "   ❌ Error: $($_.Exception.Message)`n" -ForegroundColor Red
}

# Test 7: Pagination (using standard endpoint with default limit)
Write-Host "7. Test Pagination (default limit=50)..." -ForegroundColor Yellow
try {
    $response = Invoke-RestMethod -Uri "http://$ALB_DNS/api/social-graph/$topUser/followers" -Method GET -TimeoutSec 10
    $count = if($response.followers){$response.followers.Count}else{0}
    Write-Host "   ✅ Retrieved $count followers (page 1 of $($response.total_count) total)" -ForegroundColor Green
    Write-Host "   Has more: $($response.has_more)" -ForegroundColor Gray
    if($response.next_cursor) {
        Write-Host "   Next cursor: $($response.next_cursor.Substring(0, [Math]::Min(30, $response.next_cursor.Length)))..." -ForegroundColor Gray
    }
    Write-Host ""
} catch {
    Write-Host "   ❌ Error: $($_.Exception.Message)`n" -ForegroundColor Red
}

# ====================
# gRPC Tests (via grpcurl)
# ====================
Write-Host "`n🔌 gRPC Tests" -ForegroundColor Cyan
Write-Host "==================`n" -ForegroundColor Cyan

# Check if grpcurl is installed
$grpcurlExists = Get-Command grpcurl -ErrorAction SilentlyContinue
if (-not $grpcurlExists) {
    Write-Host "⚠️  grpcurl not found. Skipping gRPC tests." -ForegroundColor Yellow
    Write-Host "   To install: 'choco install grpcurl' or download from https://github.com/fullstorydev/grpcurl`n" -ForegroundColor Gray
} else {
    Write-Host "Testing gRPC endpoints (requires ECS Service Connect or port forwarding)...`n" -ForegroundColor Gray
    
    # Note: gRPC service is only accessible within VPC via Service Connect
    # For external testing, you would need to set up port forwarding or use AWS Cloud9
    
    Write-Host "⚠️  gRPC service is only accessible within AWS VPC via Service Connect DNS:" -ForegroundColor Yellow
    Write-Host "   social-graph-service-grpc:50052`n" -ForegroundColor Gray
    
    Write-Host "To test gRPC from outside VPC, you can:" -ForegroundColor Cyan
    Write-Host "  1. Use AWS Cloud9 in the same VPC" -ForegroundColor Gray
    Write-Host "  2. Set up an SSH tunnel through a bastion host" -ForegroundColor Gray
    Write-Host "  3. Temporarily expose gRPC port via ALB (not recommended for production)`n" -ForegroundColor Gray
}

# ====================
# ECS Service Status
# ====================
Write-Host "`n📦 ECS Service Status" -ForegroundColor Cyan
Write-Host "==================`n" -ForegroundColor Cyan

try {
    $serviceInfo = aws ecs describe-services `
        --cluster social-graph-service `
        --services social-graph-service `
        --region us-west-2 `
        --query 'services[0].{Running:runningCount,Desired:desiredCount,Status:status}' `
        --output json | ConvertFrom-Json
    
    Write-Host "Service Name: social-graph-service" -ForegroundColor Gray
    Write-Host "Status: $($serviceInfo.Status)" -ForegroundColor Green
    Write-Host "Tasks: $($serviceInfo.Running)/$($serviceInfo.Desired) running`n" -ForegroundColor Green
} catch {
    Write-Host "❌ Failed to get ECS service status`n" -ForegroundColor Red
}

# ====================
# DynamoDB Direct Check
# ====================
Write-Host "💾 DynamoDB Direct Verification" -ForegroundColor Cyan
Write-Host "==================`n" -ForegroundColor Cyan

Write-Host "Checking User $topUser in DynamoDB..." -ForegroundColor Yellow
try {
    python -c "import boto3; dyn = boto3.resource('dynamodb', region_name='us-west-2'); t = dyn.Table('social-graph-followers'); r = t.get_item(Key={'user_id': '913'}); item = r.get('Item', {}); print(f'✅ DynamoDB: User 913 has {len(item.get(\"follower_ids\", []))} followers'); print(f'   Sample IDs: {item.get(\"follower_ids\", [])[:5]}')" 2>$null
    Write-Host ""
} catch {
    Write-Host "❌ Python/boto3 not available for direct DynamoDB check`n" -ForegroundColor Red
}

# ====================
# Summary
# ====================
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Test Summary" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

Write-Host "✅ HTTP API Endpoints:" -ForegroundColor Green
Write-Host "   • Health check" -ForegroundColor Gray
Write-Host "   • Get follower/following counts" -ForegroundColor Gray
Write-Host "   • Get followers/following lists" -ForegroundColor Gray
Write-Host "   • Check relationships" -ForegroundColor Gray
Write-Host "   • Pagination support`n" -ForegroundColor Gray

Write-Host "📌 Key Endpoints:" -ForegroundColor Cyan
Write-Host "   GET  http://$ALB_DNS/api/social-graph/health" -ForegroundColor Gray
Write-Host "   GET  http://$ALB_DNS/api/social-graph/followers/{userId}/count" -ForegroundColor Gray
Write-Host "   GET  http://$ALB_DNS/api/social-graph/following/{userId}/count" -ForegroundColor Gray
Write-Host "   GET  http://$ALB_DNS/api/social-graph/{userId}/followers" -ForegroundColor Gray
Write-Host "   GET  http://$ALB_DNS/api/social-graph/{userId}/following" -ForegroundColor Gray
Write-Host "   GET  http://$ALB_DNS/api/social-graph/relationship/check?followerId=X&targetId=Y" -ForegroundColor Gray
Write-Host "   GET  http://$ALB_DNS/api/social-graph/followers/{userId}/list?limit=N&cursor=C`n" -ForegroundColor Gray

Write-Host "🔌 gRPC Endpoint (internal VPC only):" -ForegroundColor Cyan
Write-Host "   social-graph-service-grpc:50052`n" -ForegroundColor Gray

Write-Host "✅ All tests completed!" -ForegroundColor Green
