#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Paths to existing scripts
SOCIAL_GRAPH_SCRIPT="$PROJECT_ROOT/services/social-graph-services/scripts/generate_and_load.sh"

# Default values
NUM_USERS=25000
BASE_URL=""  # Will be read from Terraform output
CONCURRENCY=50
AWS_REGION="us-west-2"
FOLLOWERS_TABLE="social-graph-followers"
FOLLOWING_TABLE="social-graph-following"
AUTO_YES=false


echo ""
echo -e "${BLUE}================================================================${NC}"
echo -e "${BLUE}Step 2: Creating Relationships via Social Graph DynamoDB${NC}"
echo -e "${BLUE}================================================================${NC}"
echo ""

# Run Social Graph script (ensure per-service venv and deps)
SOCIAL_SCRIPTS_DIR="$PROJECT_ROOT/services/social-graph-services/scripts"
cd "$SOCIAL_SCRIPTS_DIR"
bash generate_and_load.sh \
    --users "$NUM_USERS" \
    --region "$AWS_REGION" \
    --followers-table "$FOLLOWERS_TABLE" \
    --following-table "$FOLLOWING_TABLE"

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

