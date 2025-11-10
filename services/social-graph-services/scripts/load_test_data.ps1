# Load test data into DynamoDB tables for social-graph-service
# Usage: .\load_test_data.ps1 [-Users 5000]

param(
    [int]$Users = 5000,
    [string]$FollowersTable = $env:FOLLOWERS_TABLE_NAME ?? "social-graph-followers",
    [string]$FollowingTable = $env:FOLLOWING_TABLE_NAME ?? "social-graph-following",
    [string]$AwsRegion = $env:AWS_REGION ?? "us-west-2"
)

Write-Host "🚀 Loading social graph test data" -ForegroundColor Cyan
Write-Host "==================================" -ForegroundColor Cyan
Write-Host "Users: $Users"
Write-Host "Followers table: $FollowersTable"
Write-Host "Following table: $FollowingTable"
Write-Host "AWS Region: $AwsRegion"
Write-Host ""

# Check if boto3 is installed
try {
    python -c "import boto3" 2>$null
} catch {
    Write-Host "📦 Installing Python dependencies..." -ForegroundColor Yellow
    pip install -r requirements.txt
}

# Run the load script
Write-Host "🔄 Generating and loading data..." -ForegroundColor Yellow
python load_dynamodb.py `
    --users $Users `
    --followers-table $FollowersTable `
    --following-table $FollowingTable `
    --region $AwsRegion

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "✅ Data loading complete!" -ForegroundColor Green
} else {
    Write-Host ""
    Write-Host "❌ Data loading failed!" -ForegroundColor Red
    exit 1
}
