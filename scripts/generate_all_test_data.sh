#!/bin/bash
#
# Complete Test Data Generation
# Orchestrates existing scripts to create users and relationships
#
# Step 1: Create users via User Service API
# Step 2: Create relationships via Social Graph direct DynamoDB write
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Paths to existing scripts
USER_SERVICE_SCRIPT="$PROJECT_ROOT/services/user-service/scripts/generate_test_data.py"
SOCIAL_GRAPH_SCRIPT="$PROJECT_ROOT/services/social-graph-services/scripts/generate_and_load.sh"

# Default values
NUM_USERS=25000
BASE_URL=""  # Will be read from Terraform output
CONCURRENCY=50
AWS_REGION="us-west-2"
FOLLOWERS_TABLE="social-graph-followers"
FOLLOWING_TABLE="social-graph-following"
AUTO_YES=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --users)
            NUM_USERS="$2"
            shift 2
            ;;
        --base-url)
            BASE_URL="$2"
            shift 2
            ;;
        --concurrency)
            CONCURRENCY="$2"
            shift 2
            ;;
        --region)
            AWS_REGION="$2"
            shift 2
            ;;
        -y|--yes)
            AUTO_YES=true
            shift
            ;;
        --help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Orchestrates existing scripts to generate complete test data:"
            echo "  1. Creates users via User Service API"
            echo "  2. Creates relationships via Social Graph DynamoDB"
            echo ""
            echo "Options:"
            echo "  --users NUM          Number of users (default: 5000)"
            echo "  --base-url URL       API base URL (default: auto-detect from Terraform)"
            echo "  --concurrency NUM    User creation concurrency (default: 50)"
            echo "  --region REGION      AWS region (default: us-west-2)"
            echo "  -y, --yes            Auto-confirm without prompting"
            echo "  --help               Show this help message"
            echo ""
            echo "ALB URL Detection:"
            echo "  By default, the script reads ALB URL from Terraform output:"
            echo "    terraform output -raw alb_dns_name"
            echo ""
            echo "  If Terraform is not available, provide --base-url manually:"
            echo "    $0 --base-url http://your-alb-url.com"
            echo ""
            echo "Examples:"
            echo "  $0                                    # Auto-detect ALB, 5K users"
            echo "  $0 --users 10000 --yes                # Auto-detect ALB, 10K users, no prompt"
            echo "  $0 --users 25000 --concurrency 100    # Auto-detect ALB, 25K users, 100 concurrent"
            echo "  $0 --base-url http://my-alb.com       # Manual ALB URL"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Run '$0 --help' for usage information"
            exit 1
            ;;
    esac
done

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Get ALB URL from Terraform output if not provided
if [ -z "$BASE_URL" ]; then
    echo ""
    echo -e "${BLUE}📡 Reading ALB URL from Terraform output...${NC}"
    
    TERRAFORM_DIR="$PROJECT_ROOT/terraform"
    
    if [ ! -d "$TERRAFORM_DIR" ]; then
        echo -e "${RED}❌ Error: Terraform directory not found at: $TERRAFORM_DIR${NC}"
        exit 1
    fi
    
    cd "$TERRAFORM_DIR"
    
    # Try to get ALB DNS from Terraform output
    ALB_DNS=$(terraform output -raw alb_dns_name 2>/dev/null)
    
    if [ $? -ne 0 ] || [ -z "$ALB_DNS" ]; then
        echo -e "${RED}❌ Error: Failed to read ALB DNS from Terraform output${NC}"
        echo ""
        echo "Please ensure:"
        echo "  1. Terraform has been applied: cd terraform && terraform apply"
        echo "  2. ALB output exists: terraform output alb_dns_name"
        echo ""
        echo "Or provide --base-url manually:"
        echo "  $0 --base-url http://your-alb-url.com"
        exit 1
    fi
    
    BASE_URL="http://${ALB_DNS}"
    echo -e "${GREEN}✅ ALB URL: $BASE_URL${NC}"
    
    cd "$SCRIPT_DIR"
fi

echo ""
echo -e "${BLUE}================================================================${NC}"
echo -e "${BLUE}        Complete Test Data Generation (via Scripts)${NC}"
echo -e "${BLUE}================================================================${NC}"
echo ""
echo -e "${BLUE}This will:${NC}"
echo "  1. Create $NUM_USERS users via User Service API (~2-3 minutes)"
echo "  2. Create relationships via Social Graph DynamoDB (~30 seconds)"
echo ""
echo -e "${GREEN}Configuration:${NC}"
echo "  Users:       $NUM_USERS"
echo "  Base URL:    $BASE_URL"
echo "  Concurrency: $CONCURRENCY"
echo "  Region:      $AWS_REGION"
echo ""

# Confirm
if [ "$AUTO_YES" = false ]; then
    read -p "Continue? (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Aborted."
        exit 0
    fi
else
    echo "Auto-confirming (--yes flag provided)..."
fi

# Check if scripts exist
if [ ! -f "$USER_SERVICE_SCRIPT" ]; then
    echo -e "${RED}❌ Error: User Service script not found at:${NC}"
    echo "   $USER_SERVICE_SCRIPT"
    exit 1
fi

if [ ! -f "$SOCIAL_GRAPH_SCRIPT" ]; then
    echo -e "${RED}❌ Error: Social Graph script not found at:${NC}"
    echo "   $SOCIAL_GRAPH_SCRIPT"
    exit 1
fi

# Check Python
if ! command -v python3 &> /dev/null; then
    echo -e "${RED}❌ Error: python3 not found${NC}"
    exit 1
fi


# Helper: create and activate venv inside a service scripts directory
create_and_activate_service_venv() {
    local service_scripts_dir="$1"
    local venv_dir="$service_scripts_dir/.venv"
    local req_file="$service_scripts_dir/requirements.txt"

    echo "\nSetting up virtualenv in $service_scripts_dir"
    if [ ! -d "$venv_dir" ]; then
        python3 -m venv "$venv_dir"
    fi

    # shellcheck source=/dev/null
    . "$venv_dir/bin/activate"
    python -m pip install --upgrade pip setuptools wheel

    if [ -f "$req_file" ]; then
        echo "Installing packages from $req_file"
        python -m pip install -r "$req_file"
    else
        echo "No requirements.txt in $service_scripts_dir, installing minimal packages"
        python -m pip install aiohttp boto3 requests
    fi
}

deactivate_venv() {
    if [ -n "${VIRTUAL_ENV-}" ]; then
        deactivate || true
    fi
}

START_TIME=$(date +%s)

echo ""
echo -e "${BLUE}================================================================${NC}"
echo -e "${BLUE}Step 1: Creating Users via User Service API${NC}"
echo -e "${BLUE}================================================================${NC}"
echo ""

# Run User Service script (ensure per-service venv and deps)
USER_SCRIPTS_DIR="$PROJECT_ROOT/services/user-service/scripts"
create_and_activate_service_venv "$USER_SCRIPTS_DIR"
cd "$USER_SCRIPTS_DIR"
python3 generate_test_data.py \
    "$NUM_USERS" \
    --url "$BASE_URL" \
    --concurrency "$CONCURRENCY"
deactivate_venv

USER_EXIT_CODE=$?

if [ $USER_EXIT_CODE -ne 0 ]; then
    echo ""
    echo -e "${RED}❌ User creation failed with exit code $USER_EXIT_CODE${NC}"
    echo "Aborting..."
    exit $USER_EXIT_CODE
fi

echo ""
echo -e "${GREEN}✅ Step 1 completed: Users created${NC}"
echo ""

# Wait a moment for services to stabilize
echo "⏳ Waiting 5 seconds for services to stabilize..."
sleep 5

echo ""
echo -e "${BLUE}================================================================${NC}"
echo -e "${BLUE}Step 2: Creating Relationships via Social Graph DynamoDB${NC}"
echo -e "${BLUE}================================================================${NC}"
echo ""

# Run Social Graph script (ensure per-service venv and deps)
SOCIAL_SCRIPTS_DIR="$PROJECT_ROOT/services/social-graph-services/scripts"
create_and_activate_service_venv "$SOCIAL_SCRIPTS_DIR"
cd "$SOCIAL_SCRIPTS_DIR"
bash generate_and_load.sh \
    --users "$NUM_USERS" \
    --region "$AWS_REGION" \
    --followers-table "$FOLLOWERS_TABLE" \
    --following-table "$FOLLOWING_TABLE"
deactivate_venv

SOCIAL_EXIT_CODE=$?

if [ $SOCIAL_EXIT_CODE -ne 0 ]; then
    echo ""
    echo -e "${RED}❌ Relationship creation failed with exit code $SOCIAL_EXIT_CODE${NC}"
    exit $SOCIAL_EXIT_CODE
fi

END_TIME=$(date +%s)
TOTAL_TIME=$((END_TIME - START_TIME))
TOTAL_MINUTES=$((TOTAL_TIME / 60))
TOTAL_SECONDS=$((TOTAL_TIME % 60))

echo ""
echo -e "${GREEN}✅ Step 2 completed: Relationships created${NC}"
echo ""
echo -e "${BLUE}================================================================${NC}"
echo -e "${GREEN}✅ Complete Test Data Generation Finished!${NC}"
echo -e "${BLUE}================================================================${NC}"
echo ""
echo -e "${GREEN}Summary:${NC}"
echo "  Total users:        $NUM_USERS"
echo "  Total relationships: ~$((NUM_USERS * 40)) (estimated)"
echo "  Total time:         ${TOTAL_MINUTES}m ${TOTAL_SECONDS}s"
echo ""
echo -e "${BLUE}Next steps:${NC}"
echo "  1. Verify user creation:"
echo "     curl $BASE_URL/api/users/1"
echo ""
echo "  2. Verify relationships:"
echo "     curl $BASE_URL/api/social-graph/followers/913/count"
echo ""
echo "  3. Run timeline test:"
echo "     cd $PROJECT_ROOT/scripts"
echo "     python3 test_timeline_flow.py"
echo ""
echo -e "${BLUE}================================================================${NC}"

