#!/bin/bash
##############################################################################
# Generate Social Graph Test Data and Load to DynamoDB
# 
# This script generates social graph relationships with a power-law distribution
# and loads the data into AWS DynamoDB tables.
#
# Usage:
#   ./generate_and_load.sh [OPTIONS]
#
# Options:
#   --users NUM            Number of users (default: 5000)
#   --followers-table NAME Followers table name (default: social-graph-followers)
#   --following-table NAME Following table name (default: social-graph-following)
#   --region REGION        AWS region (default: us-west-2)
#   --help                 Show this help message
#
# Distribution:
#   - Small tier (80%):    1 follower each
#   - Medium tier (15%):   100 followers each
#   - Big tier (4.99%):    500 followers each
#   - Top tier (0.01%):    2000 followers each
#
# Example:
#   ./generate_and_load.sh --users 10000 --region us-east-1
#
##############################################################################

set -e  # Exit on error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Default values
USERS=5000
FOLLOWERS_TABLE="${FOLLOWERS_TABLE_NAME:-social-graph-followers}"
FOLLOWING_TABLE="${FOLLOWING_TABLE_NAME:-social-graph-following}"
AWS_REGION="${AWS_REGION:-us-west-2}"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --users)
            USERS="$2"
            shift 2
            ;;
        --followers-table)
            FOLLOWERS_TABLE="$2"
            shift 2
            ;;
        --following-table)
            FOLLOWING_TABLE="$2"
            shift 2
            ;;
        --region)
            AWS_REGION="$2"
            shift 2
            ;;
        --help)
            head -n 26 "$0" | tail -n 24
            exit 0
            ;;
        *)
            echo -e "${RED}❌ Unknown option: $1${NC}"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VENV_DIR="${SCRIPT_DIR}/venv"

# Print configuration
echo -e "${CYAN}🚀 Social Graph Data Generator${NC}"
echo -e "${CYAN}===============================${NC}"
echo -e "Users:            ${USERS}"
echo -e "Followers table:  ${FOLLOWERS_TABLE}"
echo -e "Following table:  ${FOLLOWING_TABLE}"
echo -e "AWS Region:       ${AWS_REGION}"
echo ""

# Check Python installation
if ! command -v python3 &> /dev/null; then
    echo -e "${RED}❌ Error: python3 is not installed${NC}"
    exit 1
fi

# Check AWS credentials
if ! aws sts get-caller-identity &> /dev/null; then
    echo -e "${RED}❌ Error: AWS credentials not configured${NC}"
    echo "Run 'aws configure' to set up your credentials"
    exit 1
fi

echo -e "${GREEN}✅ AWS credentials configured${NC}"
echo ""

# Setup virtual environment
echo -e "${YELLOW}📦 Setting up Python virtual environment...${NC}"
if [ ! -d "${VENV_DIR}" ]; then
    echo -e "${YELLOW}Creating virtual environment...${NC}"
    python3 -m venv "${VENV_DIR}" || {
        echo -e "${RED}❌ Failed to create virtual environment${NC}"
        exit 1
    }
fi

# Activate virtual environment
source "${VENV_DIR}/bin/activate" || {
    echo -e "${RED}❌ Failed to activate virtual environment${NC}"
    exit 1
}

# Check if requirements are installed
if ! python -c "import boto3" 2>/dev/null; then
    echo -e "${YELLOW}Installing Python dependencies...${NC}"
    pip install --upgrade pip || {
        echo -e "${RED}❌ Failed to upgrade pip${NC}"
        exit 1
    }
    pip install -r "${SCRIPT_DIR}/requirements.txt" || {
        echo -e "${RED}❌ Failed to install dependencies${NC}"
        exit 1
    }
fi
echo -e "${GREEN}✅ Dependencies installed${NC}"
echo ""

# Check if DynamoDB tables exist
echo -e "${YELLOW}🔍 Checking DynamoDB tables...${NC}"
if ! aws dynamodb describe-table --table-name "${FOLLOWERS_TABLE}" --region "${AWS_REGION}" &> /dev/null; then
    echo -e "${RED}❌ Error: Table '${FOLLOWERS_TABLE}' does not exist in ${AWS_REGION}${NC}"
    echo "Please create the table first or check your AWS region"
    exit 1
fi

if ! aws dynamodb describe-table --table-name "${FOLLOWING_TABLE}" --region "${AWS_REGION}" &> /dev/null; then
    echo -e "${RED}❌ Error: Table '${FOLLOWING_TABLE}' does not exist in ${AWS_REGION}${NC}"
    echo "Please create the table first or check your AWS region"
    exit 1
fi
echo -e "${GREEN}✅ DynamoDB tables found${NC}"
echo ""

# Run the data generation and loading script
echo -e "${YELLOW}🔄 Generating and loading data...${NC}"
echo "This may take several minutes depending on the number of users..."
echo ""

python "${SCRIPT_DIR}/load_dynamodb.py" \
    --users "${USERS}" \
    --followers-table "${FOLLOWERS_TABLE}" \
    --following-table "${FOLLOWING_TABLE}" \
    --region "${AWS_REGION}" || {
    echo ""
    echo -e "${RED}❌ Data loading failed!${NC}"
    deactivate 2>/dev/null || true
    exit 1
}

# Deactivate virtual environment
deactivate 2>/dev/null || true

echo ""
echo -e "${GREEN}✅ Data loading complete!${NC}"
echo ""
echo -e "${CYAN}📊 Summary:${NC}"
echo "  • Generated relationships for ${USERS} users"
echo "  • Loaded to ${FOLLOWERS_TABLE} and ${FOLLOWING_TABLE}"
echo "  • Region: ${AWS_REGION}"
echo ""
echo -e "${CYAN}🧪 Test the data:${NC}"
echo "  # Check a top user (e.g., User 913 should have ~2000 followers)"
echo "  aws dynamodb get-item \\"
echo "    --table-name ${FOLLOWERS_TABLE} \\"
echo "    --key '{\"user_id\": {\"N\": \"913\"}}' \\"
echo "    --region ${AWS_REGION}"
echo ""
echo -e "${CYAN}🌐 Test the API:${NC}"
echo "  curl http://YOUR-ALB-DNS/api/social-graph/followers/913/count"
echo ""
