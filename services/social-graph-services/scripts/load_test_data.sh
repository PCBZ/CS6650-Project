#!/bin/bash
# Load test data into DynamoDB tables for social-graph-service
# Usage: ./load_test_data.sh [number_of_users]

set -e

# Default to 5000 users if not specified
USERS=${1:-5000}
FOLLOWERS_TABLE=${FOLLOWERS_TABLE_NAME:-social-graph-followers}
FOLLOWING_TABLE=${FOLLOWING_TABLE_NAME:-social-graph-following}
AWS_REGION=${AWS_REGION:-us-west-2}

echo "🚀 Loading social graph test data"
echo "=================================="
echo "Users: $USERS"
echo "Followers table: $FOLLOWERS_TABLE"
echo "Following table: $FOLLOWING_TABLE"
echo "AWS Region: $AWS_REGION"
echo ""

# Check if boto3 is installed
if ! python3 -c "import boto3" 2>/dev/null; then
    echo "📦 Installing Python dependencies..."
    pip3 install -r requirements.txt
fi

# Run the load script
echo "🔄 Generating and loading data..."
python3 load_dynamodb.py \
    --users "$USERS" \
    --followers-table "$FOLLOWERS_TABLE" \
    --following-table "$FOLLOWING_TABLE" \
    --region "$AWS_REGION"

echo ""
echo "✅ Data loading complete!"
