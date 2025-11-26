#!/usr/bin/env bash
set -euo pipefail

# Runner for locust_timeline_retrieve.py
# Uses preset default values - modify the variables below to change test parameters
#
# Output:
#   Generates HTML report: <report_name>.html

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
LOCUST_FILE="tests/timeline_retrieval/locust_timeline_retrieve.py"

# Activate venv if present
if [ -f "$REPO_ROOT/.venv/bin/activate" ]; then
  # shellcheck disable=SC1090
  source "$REPO_ROOT/.venv/bin/activate"
fi

# Install requirements before running locust
REQUIREMENTS_FILE="$(dirname "$0")/requirements.txt"
if [ -f "$REQUIREMENTS_FILE" ]; then
  echo "📦 Installing requirements from $REQUIREMENTS_FILE..."
  pip install -q -r "$REQUIREMENTS_FILE" || {
    echo "❌ Failed to install requirements"
    exit 1
  }
  echo "✅ Requirements installed"
fi

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

fetch_target_users() {
  echo "🎯 Selecting target users via seed_followings_posts.py..."
  local selection
  if ! selection=$(cd "$REPO_ROOT" && PYTHONPATH="$REPO_ROOT:${PYTHONPATH:-}" python3 - <<'PY'
import sys
import contextlib
import io
from tests.timeline_retrieval import seed_followings_posts as sfs

# Redirect select_target_users() print to stderr so it shows in terminal
original_stdout = sys.stdout
sys.stdout = sys.stderr
try:
    max_user, eq10_user, medium_user, _ = sfs.select_target_users()
finally:
    sys.stdout = original_stdout
# Print IDs to stdout for capture
print(f"{max_user} {eq10_user} {medium_user}")
PY
); then
    echo "❌ Failed to select target users via Python script"
    exit 1
  fi

  selection=$(echo "$selection" | tr -d '\r')
  if [ -z "$selection" ]; then
    echo "❌ Empty selection output from Python script"
    exit 1
  fi

  IFS=' ' read -r MAX_USER_ID EQ10_USER_ID MEDIUM_USER_ID <<< "$selection"

  if [ -z "$MAX_USER_ID" ] || [ -z "$EQ10_USER_ID" ] || [ -z "$MEDIUM_USER_ID" ]; then
    echo "❌ Failed to parse target user IDs from selection output: $selection"
    exit 1
  fi

  export TARGET_USER_MAX="$MAX_USER_ID"
  export TARGET_USER_EQ10="$EQ10_USER_ID"
  export TARGET_USER_MEDIUM="$MEDIUM_USER_ID"

  echo "Selected target users -> max: $MAX_USER_ID, eq10: $EQ10_USER_ID, medium: $MEDIUM_USER_ID"
}

# Preset default values - modify these to change test parameters
TARGET_USER="max"
USERS=1
SPAWN_RATE=1
RUN_TIME="5m"
REPORT_NAME="Report_25K_1_User_1600_Followings_Hybrid_Mode"
REPORT_HTML="${REPORT_NAME}.html"

ALB_URL_RESOLVED=$(get_alb_from_terraform)
echo "Using ALB URL: $ALB_URL_RESOLVED"
echo "Target user type: $TARGET_USER (eq10, medium, or max)"
echo "Users: $USERS, Spawn rate: $SPAWN_RATE, Run time: $RUN_TIME"
echo "Report file: $REPORT_HTML"

# Fetch target users before running Locust
fetch_target_users

# Determine which user ID to use based on TARGET_USER
case "$TARGET_USER" in
  max)
    SELECTED_USER_ID="$TARGET_USER_MAX"
    ;;
  medium)
    SELECTED_USER_ID="$TARGET_USER_MEDIUM"
    ;;
  *)
    TARGET_USER="eq10"
    SELECTED_USER_ID="$TARGET_USER_EQ10"
    ;;
esac

echo "Using $TARGET_USER user ID: $SELECTED_USER_ID"

if [ -z "$SELECTED_USER_ID" ]; then
  echo "❌ Failed to resolve user ID for target '$TARGET_USER'"
  exit 1
fi

# Set PYTHONPATH to include project root for imports
export PYTHONPATH="$REPO_ROOT:${PYTHONPATH:-}"

# Change to the script directory
cd "$(dirname "$0")"

# Build locust command
exec locust -f locust_timeline_retrieve.py \
  --headless \
  --users "$USERS" \
  --spawn-rate "$SPAWN_RATE" \
  --run-time "$RUN_TIME" \
  --host "$ALB_URL_RESOLVED" \
  --html "$REPORT_HTML" \
  --target-user-id "$SELECTED_USER_ID"

