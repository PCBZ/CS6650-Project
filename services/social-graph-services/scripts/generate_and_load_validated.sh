#!/bin/bash
##############################################################################
# Generate Social Graph Test Data with User Validation and Load to DynamoDB
# 
# This script validates users exist in user-service via gRPC BatchGetUserInfo,
# then generates social graph relationships and loads to DynamoDB.
#
# Usage:
#   ./generate_and_load_validated.sh [OPTIONS]
#
# Options:
#   --grpc-endpoint ENDPOINT  User service gRPC endpoint (required unless --skip-validation)
#                             Example: user-service-grpc:50051 or localhost:50051
#   --max-users NUM           Maximum users to process (default: all found)
#   --followers-table NAME    Followers table (default: social-graph-followers)
#   --following-table NAME    Following table (default: social-graph-following)
#   --region REGION           AWS region (default: us-west-2)
#   --skip-validation         Skip user validation, use sequential IDs
#   --help                    Show this help message
#
# Examples:
#   # From within VPC (e.g., Cloud9, ECS task)
#   ./generate_and_load_validated.sh --grpc-endpoint user-service-grpc:50051
#
#   # Via port forwarding to localhost
#   ./generate_and_load_validated.sh --grpc-endpoint localhost:50051 --max-users 5000
#
#   # Skip validation (testing only)
#   ./generate_and_load_validated.sh --skip-validation --max-users 5000
#
##############################################################################

set -e  # Exit on error

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# Default values
GRPC_ENDPOINT=""
MAX_USERS=""
FOLLOWERS_TABLE="${FOLLOWERS_TABLE_NAME:-social-graph-followers}"
FOLLOWING_TABLE="${FOLLOWING_TABLE_NAME:-social-graph-following}"
AWS_REGION="${AWS_REGION:-us-west-2}"
SKIP_VALIDATION=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --grpc-endpoint)
            GRPC_ENDPOINT="$2"
            shift 2
            ;;
        --max-users)
            MAX_USERS="$2"
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
        --skip-validation)
            SKIP_VALIDATION=true
            shift
            ;;
        --help)
            head -n 29 "$0" | tail -n 27
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

# Print configuration
echo -e "${CYAN}🚀 Social Graph Data Generator (with User Validation)${NC}"
echo -e "${CYAN}=======================================================${NC}"
if [ "$SKIP_VALIDATION" = true ]; then
    echo -e "${YELLOW}⚠️  User validation: SKIPPED (using sequential IDs)${NC}"
    echo -e "Max users:        ${MAX_USERS:-5000}"
else
    echo -e "gRPC endpoint:    ${GRPC_ENDPOINT}"
    echo -e "Max users:        ${MAX_USERS:-all found}"
fi
echo -e "Followers table:  ${FOLLOWERS_TABLE}"
echo -e "Following table:  ${FOLLOWING_TABLE}"
echo -e "AWS Region:       ${AWS_REGION}"
echo ""

# Validate required parameters
if [ "$SKIP_VALIDATION" = false ] && [ -z "$GRPC_ENDPOINT" ]; then
    echo -e "${RED}❌ Error: --grpc-endpoint is required${NC}"
    echo ""
    echo "Examples:"
    echo "  # From VPC:"
    echo "  ./generate_and_load_validated.sh --grpc-endpoint user-service-grpc:50051"
    echo ""
    echo "  # Via port forward:"
    echo "  ./generate_and_load_validated.sh --grpc-endpoint localhost:50051"
    echo ""
    echo "  # Skip validation (testing):"
    echo "  ./generate_and_load_validated.sh --skip-validation --max-users 5000"
    exit 1
fi

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

# Check if requirements are installed
echo -e "${YELLOW}📦 Checking Python dependencies...${NC}"
if ! python3 -c "import boto3" 2>/dev/null; then
    echo -e "${YELLOW}Installing Python dependencies...${NC}"
    pip3 install -r "${SCRIPT_DIR}/requirements.txt" || {
        echo -e "${RED}❌ Failed to install dependencies${NC}"
        exit 1
    }
fi

# Check if grpcio is installed (required for gRPC)
if ! python3 -c "import grpc" 2>/dev/null; then
    echo -e "${YELLOW}Installing gRPC Python libraries...${NC}"
    pip3 install grpcio grpcio-tools || {
        echo -e "${RED}❌ Failed to install gRPC dependencies${NC}"
        exit 1
    }
fi
echo -e "${GREEN}✅ Dependencies installed${NC}"
echo ""

# Check if proto files are generated
PROTO_DIR="${SCRIPT_DIR}/../../../proto"
if [ ! -f "${PROTO_DIR}/user_service_pb2.py" ]; then
    echo -e "${YELLOW}📝 Generating Python proto files...${NC}"
    cd "${PROTO_DIR}"
    python3 -m grpc_tools.protoc -I. --python_out=. --grpc_python_out=. user_service.proto || {
        echo -e "${RED}❌ Failed to generate proto files${NC}"
        exit 1
    }
    cd "${SCRIPT_DIR}"
    echo -e "${GREEN}✅ Proto files generated${NC}"
    echo ""
fi

# Check if DynamoDB tables exist
echo -e "${YELLOW}🔍 Checking DynamoDB tables...${NC}"
if ! aws dynamodb describe-table --table-name "${FOLLOWERS_TABLE}" --region "${AWS_REGION}" &> /dev/null; then
    echo -e "${RED}❌ Error: Table '${FOLLOWERS_TABLE}' does not exist in ${AWS_REGION}${NC}"
    echo "Please create the table first using Terraform"
    exit 1
fi

if ! aws dynamodb describe-table --table-name "${FOLLOWING_TABLE}" --region "${AWS_REGION}" &> /dev/null; then
    echo -e "${RED}❌ Error: Table '${FOLLOWING_TABLE}' does not exist in ${AWS_REGION}${NC}"
    echo "Please create the table first using Terraform"
    exit 1
fi
echo -e "${GREEN}✅ DynamoDB tables found${NC}"
echo ""

# Build command
CMD="python3 \"${SCRIPT_DIR}/load_dynamodb_with_validation.py\""

if [ "$SKIP_VALIDATION" = true ]; then
    CMD="$CMD --skip-validation"
    if [ -n "$MAX_USERS" ]; then
        CMD="$CMD --max-users ${MAX_USERS}"
    fi
else
    CMD="$CMD --grpc-endpoint \"${GRPC_ENDPOINT}\""
    if [ -n "$MAX_USERS" ]; then
        CMD="$CMD --max-users ${MAX_USERS}"
    fi
fi

CMD="$CMD --followers-table \"${FOLLOWERS_TABLE}\""
CMD="$CMD --following-table \"${FOLLOWING_TABLE}\""
CMD="$CMD --region \"${AWS_REGION}\""

# Run the data generation and loading script
echo -e "${YELLOW}🔄 Generating and loading data...${NC}"
echo "This may take several minutes..."
echo ""

eval $CMD || {
    echo ""
    echo -e "${RED}❌ Data loading failed!${NC}"
    exit 1
}

echo ""
echo -e "${GREEN}✅ Data loading complete!${NC}"
echo ""
echo -e "${CYAN}🧪 Test the data:${NC}"
echo "  # Check follower counts via API"
echo "  curl http://YOUR-ALB-DNS/api/social-graph/followers/USER_ID/count"
echo ""
echo -e "${CYAN}📊 Verify in DynamoDB:${NC}"
echo "  aws dynamodb scan --table-name ${FOLLOWERS_TABLE} --select COUNT --region ${AWS_REGION}"
echo ""
