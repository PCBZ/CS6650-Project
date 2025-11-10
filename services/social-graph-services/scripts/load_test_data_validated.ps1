# Load test data into DynamoDB with user validation from user-service
# Usage: .\load_test_data_validated.ps1 [OPTIONS]

param(
    [string]$GrpcEndpoint = "",
    [int]$MaxUsers = 0,
    [string]$FollowersTable = $env:FOLLOWERS_TABLE_NAME ?? "social-graph-followers",
    [string]$FollowingTable = $env:FOLLOWING_TABLE_NAME ?? "social-graph-following",
    [string]$AwsRegion = $env:AWS_REGION ?? "us-west-2",
    [switch]$SkipValidation,
    [switch]$Help
)

if ($Help) {
    Write-Host @"
Generate Social Graph Test Data with User Validation and Load to DynamoDB

This script validates users exist in user-service via gRPC BatchGetUserInfo,
then generates social graph relationships and loads to DynamoDB.

Usage:
  .\load_test_data_validated.ps1 [OPTIONS]

Options:
  -GrpcEndpoint ENDPOINT    User service gRPC endpoint (required unless -SkipValidation)
                            Example: user-service-grpc:50051 or localhost:50051
  -MaxUsers NUM             Maximum users to process (default: all found)
  -FollowersTable NAME      Followers table (default: social-graph-followers)
  -FollowingTable NAME      Following table (default: social-graph-following)
  -AwsRegion REGION         AWS region (default: us-west-2)
  -SkipValidation           Skip user validation, use sequential IDs
  -Help                     Show this help message

Examples:
  # From within VPC (e.g., ECS task with Service Connect)
  .\load_test_data_validated.ps1 -GrpcEndpoint "user-service-grpc:50051"

  # Via port forwarding to localhost
  .\load_test_data_validated.ps1 -GrpcEndpoint "localhost:50051" -MaxUsers 5000

  # Skip validation (testing only)
  .\load_test_data_validated.ps1 -SkipValidation -MaxUsers 5000
"@
    exit 0
}

Write-Host "🚀 Social Graph Data Generator (with User Validation)" -ForegroundColor Cyan
Write-Host "=======================================================" -ForegroundColor Cyan

if ($SkipValidation) {
    Write-Host "⚠️  User validation: SKIPPED (using sequential IDs)" -ForegroundColor Yellow
    Write-Host "Max users:        $($MaxUsers -gt 0 ? $MaxUsers : 5000)"
} else {
    Write-Host "gRPC endpoint:    $GrpcEndpoint"
    Write-Host "Max users:        $($MaxUsers -gt 0 ? $MaxUsers : 'all found')"
}
Write-Host "Followers table:  $FollowersTable"
Write-Host "Following table:  $FollowingTable"
Write-Host "AWS Region:       $AwsRegion"
Write-Host ""

# Validate required parameters
if (-not $SkipValidation -and [string]::IsNullOrEmpty($GrpcEndpoint)) {
    Write-Host "❌ Error: -GrpcEndpoint is required" -ForegroundColor Red
    Write-Host ""
    Write-Host "Examples:"
    Write-Host "  # From VPC:"
    Write-Host "  .\load_test_data_validated.ps1 -GrpcEndpoint 'user-service-grpc:50051'"
    Write-Host ""
    Write-Host "  # Via port forward:"
    Write-Host "  .\load_test_data_validated.ps1 -GrpcEndpoint 'localhost:50051'"
    Write-Host ""
    Write-Host "  # Skip validation (testing):"
    Write-Host "  .\load_test_data_validated.ps1 -SkipValidation -MaxUsers 5000"
    exit 1
}

# Check if boto3 is installed
Write-Host "📦 Checking Python dependencies..." -ForegroundColor Yellow
try {
    python -c "import boto3" 2>$null
    if ($LASTEXITCODE -ne 0) { throw }
} catch {
    Write-Host "Installing Python dependencies..." -ForegroundColor Yellow
    pip install -r requirements.txt
    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ Failed to install dependencies" -ForegroundColor Red
        exit 1
    }
}

# Check if grpcio is installed
try {
    python -c "import grpc" 2>$null
    if ($LASTEXITCODE -ne 0) { throw }
} catch {
    Write-Host "Installing gRPC Python libraries..." -ForegroundColor Yellow
    pip install grpcio grpcio-tools
    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ Failed to install gRPC dependencies" -ForegroundColor Red
        exit 1
    }
}

Write-Host "✅ Dependencies installed" -ForegroundColor Green
Write-Host ""

# Check if proto files are generated
$protoDir = Join-Path $PSScriptRoot "..\..\..\proto"
$protoFile = Join-Path $protoDir "user_service_pb2.py"

if (-not (Test-Path $protoFile)) {
    Write-Host "📝 Generating Python proto files..." -ForegroundColor Yellow
    Push-Location $protoDir
    python -m grpc_tools.protoc -I. --python_out=. --grpc_python_out=. user_service.proto
    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ Failed to generate proto files" -ForegroundColor Red
        Pop-Location
        exit 1
    }
    Pop-Location
    Write-Host "✅ Proto files generated" -ForegroundColor Green
    Write-Host ""
}

# Check AWS credentials
try {
    aws sts get-caller-identity 2>$null | Out-Null
    if ($LASTEXITCODE -ne 0) { throw }
    Write-Host "✅ AWS credentials configured" -ForegroundColor Green
} catch {
    Write-Host "❌ Error: AWS credentials not configured" -ForegroundColor Red
    Write-Host "Run 'aws configure' to set up your credentials"
    exit 1
}
Write-Host ""

# Check if DynamoDB tables exist
Write-Host "🔍 Checking DynamoDB tables..." -ForegroundColor Yellow
try {
    aws dynamodb describe-table --table-name $FollowersTable --region $AwsRegion 2>$null | Out-Null
    if ($LASTEXITCODE -ne 0) { throw }
} catch {
    Write-Host "❌ Error: Table '$FollowersTable' does not exist in $AwsRegion" -ForegroundColor Red
    Write-Host "Please create the table first using Terraform"
    exit 1
}

try {
    aws dynamodb describe-table --table-name $FollowingTable --region $AwsRegion 2>$null | Out-Null
    if ($LASTEXITCODE -ne 0) { throw }
} catch {
    Write-Host "❌ Error: Table '$FollowingTable' does not exist in $AwsRegion" -ForegroundColor Red
    Write-Host "Please create the table first using Terraform"
    exit 1
}

Write-Host "✅ DynamoDB tables found" -ForegroundColor Green
Write-Host ""

# Build command
$cmd = "python load_dynamodb_with_validation.py"

if ($SkipValidation) {
    $cmd += " --skip-validation"
    if ($MaxUsers -gt 0) {
        $cmd += " --max-users $MaxUsers"
    }
} else {
    $cmd += " --grpc-endpoint `"$GrpcEndpoint`""
    if ($MaxUsers -gt 0) {
        $cmd += " --max-users $MaxUsers"
    }
}

$cmd += " --followers-table `"$FollowersTable`""
$cmd += " --following-table `"$FollowingTable`""
$cmd += " --region `"$AwsRegion`""

# Run the load script
Write-Host "🔄 Generating and loading data..." -ForegroundColor Yellow
Write-Host "This may take several minutes..." -ForegroundColor Yellow
Write-Host ""

Invoke-Expression $cmd

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "✅ Data loading complete!" -ForegroundColor Green
    Write-Host ""
    Write-Host "🧪 Test the data:" -ForegroundColor Cyan
    Write-Host "  # Check follower counts via API"
    Write-Host "  curl http://YOUR-ALB-DNS/api/social-graph/followers/USER_ID/count"
    Write-Host ""
    Write-Host "📊 Verify in DynamoDB:" -ForegroundColor Cyan
    Write-Host "  aws dynamodb scan --table-name $FollowersTable --select COUNT --region $AwsRegion"
} else {
    Write-Host ""
    Write-Host "❌ Data loading failed!" -ForegroundColor Red
    exit 1
}
