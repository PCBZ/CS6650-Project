# Test gRPC Connection via HTTP Endpoint
# This script tests the user-service gRPC connection from social-graph-service

$ALB_DNS = "cs6650-project-dev-alb-315577819.us-west-2.elb.amazonaws.com"
$ENDPOINT = "http://$ALB_DNS/api/social-graph/test/user-service"

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "Testing User Service gRPC Connection" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "ALB DNS: $ALB_DNS" -ForegroundColor Yellow
Write-Host "Test Endpoint: $ENDPOINT" -ForegroundColor Yellow
Write-Host ""

Write-Host "Sending test request..." -ForegroundColor Green
$response = Invoke-RestMethod -Uri $ENDPOINT -Method GET -ErrorAction SilentlyContinue

if ($response) {
    Write-Host ""
    Write-Host "=========================================" -ForegroundColor Cyan
    Write-Host "Test Result" -ForegroundColor Cyan
    Write-Host "=========================================" -ForegroundColor Cyan
    Write-Host ""
    
    Write-Host "Status: $($response.status)" -ForegroundColor $(if ($response.status -eq "success") { "Green" } else { "Red" })
    Write-Host "Message: $($response.message)"
    
    if ($response.endpoint) {
        Write-Host "Endpoint: $($response.endpoint)" -ForegroundColor Yellow
    }
    
    if ($response.duration_ms) {
        Write-Host "Response Time: $($response.duration_ms) ms" -ForegroundColor Yellow
    }
    
    if ($response.status -eq "success") {
        Write-Host ""
        Write-Host "✅ gRPC Connection Successful!" -ForegroundColor Green
        Write-Host ""
        Write-Host "Tested User IDs: $($response.tested_ids -join ', ')"
        Write-Host "Found: $($response.found_count) users" -ForegroundColor Green
        Write-Host "Not Found: $($response.not_found_count) users" -ForegroundColor $(if ($response.not_found_count -eq 0) { "Green" } else { "Yellow" })
        
        if ($response.users) {
            Write-Host ""
            Write-Host "User Details:" -ForegroundColor Cyan
            foreach ($user in $response.users) {
                Write-Host "  - User $($user.user_id): $($user.username)"
            }
        }
        
        if ($response.not_found -and $response.not_found.Count -gt 0) {
            Write-Host ""
            Write-Host "Not Found IDs: $($response.not_found -join ', ')" -ForegroundColor Yellow
        }
    } else {
        Write-Host ""
        Write-Host "❌ gRPC Connection Failed!" -ForegroundColor Red
        if ($response.error) {
            Write-Host "Error: $($response.error)" -ForegroundColor Red
        }
    }
    
    Write-Host ""
    Write-Host "Full Response:" -ForegroundColor Gray
    $response | ConvertTo-Json -Depth 10
} else {
    Write-Host "❌ Failed to get response from endpoint" -ForegroundColor Red
}

Write-Host ""
Write-Host "=========================================" -ForegroundColor Cyan
