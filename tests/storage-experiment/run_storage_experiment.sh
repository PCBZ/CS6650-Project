#!/usr/bin/env bash
set -euo pipefail

################################################################################
# Storage Experiment Runner
#
# Generates posts and measures DynamoDB storage for different fan-out strategies.
#
# Prerequisites:
#   - Run setup_experiment_data.sh first to create users and social graph
#   - Manually clear DynamoDB tables if needed
#
# Usage:
#   ./run_storage_experiment.sh
#
# Modify the preset values below to configure the experiment.
################################################################################

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

# ============================================================================
# PRESET CONFIGURATION - Modify these values
# ============================================================================
SCALE="5K"                    # User scale: 5K, 25K, or 100K
STRATEGY="pull"               # Strategy: push, pull, or hybrid
LOCUST_USERS=100              # Number of concurrent Locust users
SPAWN_RATE=10                 # User spawn rate
RUN_TIME="10m"                # How long to generate posts
WRITE_RATIO=100               # Percentage of writes (100 = 100% posts, no timeline reads)

# ============================================================================
# Colors for output
# ============================================================================
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

# ============================================================================
# Helper Functions
# ============================================================================

get_alb_from_terraform() {
  if [ -n "${HOST_URL:-}" ]; then
    echo "$HOST_URL"
    return 0
  fi
  if [ -n "${ALB_URL:-}" ]; then
    echo "$ALB_URL"
    return 0
  fi

  TF_DIR="$REPO_ROOT/terraform"
  if [ -d "$TF_DIR" ]; then
    if command -v terraform >/dev/null 2>&1; then
      set +e
      OUT=$(cd "$TF_DIR" && terraform output -raw alb_dns_name 2>/dev/null) || OUT=""
      set -e
      if [ -n "$OUT" ]; then
        echo "http://$OUT"
        return 0
      fi
    fi
  fi
}

get_num_users() {
  case $SCALE in
    "5K")   echo 5000 ;;
    "25K")  echo 25000 ;;
    "100K") echo 100000 ;;
    *)      echo 5000 ;;
  esac
}

get_table_names() {
  # Actual DynamoDB table names from your AWS account
  POST_TABLE="posts-table"
  TIMELINE_TABLE="posts-timeline-service"
  echo "$POST_TABLE $TIMELINE_TABLE"
}

# ============================================================================
# Main Script
# ============================================================================

echo -e "${BLUE}================================================================================${NC}"
echo -e "${BLUE}                    Storage Experiment - ${SCALE} ${STRATEGY}${NC}"
echo -e "${BLUE}================================================================================${NC}"
echo ""

# Get configuration
NUM_USERS=$(get_num_users)
ALB_URL=$(get_alb_from_terraform)

if [ -z "$ALB_URL" ]; then
  echo -e "${RED}❌ Could not determine ALB URL${NC}"
  exit 1
fi

echo -e "${GREEN}Configuration:${NC}"
echo "  Scale: $SCALE ($NUM_USERS users)"
echo "  Strategy: $STRATEGY"
echo "  ALB URL: $ALB_URL"
echo "  Locust users: $LOCUST_USERS"
echo "  Run time: $RUN_TIME"
echo "  Write ratio: ${WRITE_RATIO}%"
echo ""

# Activate venv if present
if [ -f "$REPO_ROOT/.venv/bin/activate" ]; then
  # shellcheck disable=SC1090
  source "$REPO_ROOT/.venv/bin/activate"
fi

# Install requirements
REQUIREMENTS_FILE="$REPO_ROOT/tests/storage-experiment/requirements.txt"
if [ -f "$REQUIREMENTS_FILE" ]; then
  echo -e "${YELLOW}📦 Installing requirements...${NC}"
  pip install -q -r "$REQUIREMENTS_FILE" || {
    echo -e "${RED}❌ Failed to install requirements${NC}"
    exit 1
  }
  echo -e "${GREEN}✅ Requirements installed${NC}"
  echo ""
fi

# Set PYTHONPATH
export PYTHONPATH="$REPO_ROOT:${PYTHONPATH:-}"

# Create results directory
RESULTS_DIR="$REPO_ROOT/tests/storage-experiment/results"
mkdir -p "$RESULTS_DIR"

# Set AWS profile
export AWS_PROFILE=myisb_IsbUsersPS-108322181857

# ============================================================================
# Step 1: Generate Posts
# ============================================================================

echo -e "${BLUE}================================================================================${NC}"
echo -e "${BLUE}Step 1: Generating Posts with Locust${NC}"
echo -e "${BLUE}================================================================================${NC}"
echo ""

cd "$REPO_ROOT/tests/storage-experiment"

# Export custom parameters as environment variables for locust to read
export NUM_USERS="$NUM_USERS"
export WRITE_RATIO="$WRITE_RATIO"

locust -f locust_storage_test.py \
  --headless \
  --users "$LOCUST_USERS" \
  --spawn-rate "$SPAWN_RATE" \
  --run-time "$RUN_TIME" \
  --host "$ALB_URL"

echo ""
echo -e "${GREEN}✅ Post generation complete${NC}"
echo ""

# Wait for fan-out to complete
echo -e "${YELLOW}⏳ Waiting 60 seconds for fan-out to complete...${NC}"
sleep 60
echo -e "${GREEN}✅ Fan-out complete${NC}"
echo ""

# ============================================================================
# Step 2: Measure Storage
# ============================================================================

echo -e "${BLUE}================================================================================${NC}"
echo -e "${BLUE}Step 2: Measuring DynamoDB Storage${NC}"
echo -e "${BLUE}================================================================================${NC}"
echo ""

# Get table names
read -r POST_TABLE TIMELINE_TABLE <<< "$(get_table_names)"

echo -e "${YELLOW}DynamoDB Tables:${NC}"
echo "  Post Table: $POST_TABLE"
echo "  Timeline Table: $TIMELINE_TABLE"
echo ""

OUTPUT_FILE="$RESULTS_DIR/storage_metrics_${SCALE}_${STRATEGY}.json"

python3 measure_storage.py \
  --region us-west-2 \
  --post-table "$POST_TABLE" \
  --timeline-table "$TIMELINE_TABLE" \
  --output "$OUTPUT_FILE"

echo ""
echo -e "${GREEN}✅ Storage measurement saved to: $OUTPUT_FILE${NC}"
echo ""

# ============================================================================
# Done
# ============================================================================

echo -e "${BLUE}================================================================================${NC}"
echo -e "${GREEN}🎉 Storage Experiment Complete!${NC}"
echo -e "${BLUE}================================================================================${NC}"
echo ""
echo -e "${GREEN}Results:${NC}"
echo "  Storage metrics: $OUTPUT_FILE"
echo ""
echo -e "${BLUE}Next steps:${NC}"
echo "  1. View storage metrics:"
echo "     cat $OUTPUT_FILE"
echo ""
echo "  2. Run for other strategies (edit STRATEGY variable):"
echo "     - push"
echo "     - pull"
echo "     - hybrid"
echo ""
echo "  3. Compare results:"
echo "     python3 compare_scales.py --help"
echo ""
