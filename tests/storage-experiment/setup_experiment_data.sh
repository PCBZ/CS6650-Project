#!/usr/bin/env bash
set -euo pipefail

################################################################################
# Setup Experiment Data
#
# Creates users and social graph for storage experiments.
# Run this ONCE before running storage experiments.
#
# Usage:
#   ./setup_experiment_data.sh [SCALE]
#
# Arguments:
#   SCALE - User scale: 5K, 25K, or 100K (default: 5K)
################################################################################

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

# ============================================================================
# Configuration
# ============================================================================
SCALE="${1:-5K}"  # Default to 5K if not provided

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

# ============================================================================
# Main Script
# ============================================================================

echo -e "${BLUE}================================================================================${NC}"
echo -e "${BLUE}                    Setup Experiment Data - ${SCALE}${NC}"
echo -e "${BLUE}================================================================================${NC}"
echo ""

# Get configuration
NUM_USERS=$(get_num_users)
ALB_URL=$(get_alb_from_terraform)

if [ -z "$ALB_URL" ]; then
  echo -e "${RED}❌ Could not determine ALB URL${NC}"
  echo -e "${YELLOW}Please set HOST_URL or ALB_URL environment variable${NC}"
  exit 1
fi

echo -e "${GREEN}Configuration:${NC}"
echo "  Scale: $SCALE ($NUM_USERS users)"
echo "  ALB URL: $ALB_URL"
echo ""

# Set AWS profile
export AWS_PROFILE=myisb_IsbUsersPS-108322181857

# ============================================================================
# Step 1: Check/Seed Users
# ============================================================================

echo -e "${BLUE}================================================================================${NC}"
echo -e "${BLUE}Step 1: Checking/Creating Users${NC}"
echo -e "${BLUE}================================================================================${NC}"
echo ""

# Check if users already exist
USER_COUNT=$(aws dynamodb describe-table --table-name users --region us-west-2 --query 'Table.ItemCount' --output text 2>/dev/null || echo "0")

if [ "$USER_COUNT" -ge "$NUM_USERS" ]; then
  echo -e "${GREEN}✅ Users already exist ($USER_COUNT >= $NUM_USERS required)${NC}"
  echo -e "${YELLOW}Skipping user creation. Delete users table to recreate.${NC}"
else
  echo -e "${YELLOW}Generating $NUM_USERS users...${NC}"
  case $SCALE in
    "5K")
      (cd "$REPO_ROOT/services/user-service/scripts" && ./generate_5k_users.sh "$ALB_URL")
      ;;
    "25K")
      (cd "$REPO_ROOT/services/user-service/scripts" && ./generate_25k_users.sh "$ALB_URL")
      ;;
    "100K")
      (cd "$REPO_ROOT/services/user-service/scripts" && ./generate_100k_users.sh "$ALB_URL")
      ;;
    *)
      echo -e "${RED}❌ Invalid scale: $SCALE (must be 5K, 25K, or 100K)${NC}"
      exit 1
      ;;
  esac
  echo -e "${GREEN}✅ Users seeded${NC}"
fi
echo ""

# ============================================================================
# Step 2: Check/Seed Social Graph
# ============================================================================

echo -e "${BLUE}================================================================================${NC}"
echo -e "${BLUE}Step 2: Checking/Creating Social Graph${NC}"
echo -e "${BLUE}================================================================================${NC}"
echo ""

# Check if BOTH social graph tables have data
FOLLOWER_COUNT=$(aws dynamodb describe-table --table-name social-graph-followers --region us-west-2 --query 'Table.ItemCount' --output text 2>/dev/null || echo "0")
FOLLOWING_COUNT=$(aws dynamodb describe-table --table-name social-graph-following --region us-west-2 --query 'Table.ItemCount' --output text 2>/dev/null || echo "0")

# Need both tables to have data for a complete social graph
if [ "$FOLLOWER_COUNT" -ge 100 ] && [ "$FOLLOWING_COUNT" -ge 100 ]; then
  echo -e "${GREEN}✅ Social graph already exists (followers: $FOLLOWER_COUNT, following: $FOLLOWING_COUNT)${NC}"
  echo -e "${YELLOW}Skipping social graph creation. Clear tables to recreate.${NC}"
else
  echo -e "${YELLOW}Generating social graph for $NUM_USERS users...${NC}"
  echo -e "${YELLOW}Current state - followers: $FOLLOWER_COUNT, following: $FOLLOWING_COUNT${NC}"
  (cd "$REPO_ROOT/services/social-graph-services/scripts" && ./generate_and_load.sh \
    --users "$NUM_USERS" \
    --followers-table "social-graph-followers" \
    --following-table "social-graph-following" \
    --region us-west-2)
  echo -e "${GREEN}✅ Social graph seeded${NC}"
fi
echo ""

# ============================================================================
# Done
# ============================================================================

echo -e "${BLUE}================================================================================${NC}"
echo -e "${GREEN}🎉 Setup Complete!${NC}"
echo -e "${BLUE}================================================================================${NC}"
echo ""
echo -e "${GREEN}Summary:${NC}"
echo "  Users: $NUM_USERS ($SCALE)"
echo "  Social graph: Generated"
echo ""
echo -e "${BLUE}Next steps:${NC}"
echo "  1. Clear post and timeline tables manually if needed:"
echo "     - Delete and recreate tables in AWS Console, or"
echo "     - Use Terraform to recreate tables"
echo ""
echo "  2. Run storage experiment:"
echo "     ./run_storage_experiment.sh"
echo ""
