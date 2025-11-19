#!/usr/bin/env bash
set -euo pipefail

# Runner for locust_timeline_retrieve.py
# Usage: 
#   tests/timeline_retrieval/run_locust_timeline_retrieve.sh [--users N] [--spawn-rate N] [--run-time 5m] [--target eq10|medium|max] [--report NAME]
#
# Arguments:
#   --users N: Number of concurrent users (default: 1)
#   --spawn-rate N: Users to spawn per second (default: 1)
#   --run-time TIME: Test duration, e.g., "5m", "1h" (default: 1m)
#   --target TYPE: Target user type - eq10, medium, or max (default: eq10)
#   --report NAME: Report file name prefix (default: timeline_retrieve_<target>_<timestamp>)
#
# Environment variables:
#   TARGET_USER: Target user type (eq10, medium, max) - default: eq10
#   ALB_URL or HOST_URL: Override ALB URL
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

# Parse command line arguments
TARGET_USER="${TARGET_USER:-eq10}"
USERS=1
SPAWN_RATE=1
RUN_TIME="1m"
REPORT_NAME="Report_10_Followings"

while [[ $# -gt 0 ]]; do
  case $1 in
    --target)
      TARGET_USER="$2"
      shift 2
      ;;
    --users)
      USERS="$2"
      shift 2
      ;;
    --spawn-rate)
      SPAWN_RATE="$2"
      shift 2
      ;;
    --run-time)
      RUN_TIME="$2"
      shift 2
      ;;
    --report)
      REPORT_NAME="$2"
      shift 2
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

# Generate default report name if not specified
if [ -z "$REPORT_NAME" ]; then
  TIMESTAMP=$(date +%Y%m%d_%H%M%S)
  REPORT_NAME="timeline_retrieve_${TARGET_USER}_${TIMESTAMP}"
fi

REPORT_HTML="${REPORT_NAME}.html"

ALB_URL_RESOLVED=$(get_alb_from_terraform)
echo "Using ALB URL: $ALB_URL_RESOLVED"
echo "Target user type: $TARGET_USER (eq10, medium, or max)"
echo "Users: $USERS, Spawn rate: $SPAWN_RATE, Run time: $RUN_TIME"
echo "Report file: $REPORT_HTML"

# Export TARGET_USER for the Python script
export TARGET_USER

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
  --html "$REPORT_HTML"

