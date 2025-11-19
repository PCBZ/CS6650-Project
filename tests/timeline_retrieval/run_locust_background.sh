#!/usr/bin/env bash
set -euo pipefail

# Simple runner for locust_push_fanout_test.py placed inside tests/timeline_retrieval
# Usage: tests/timeline_retrieval/run_locust_push_fanout.sh [mode] [--users N] [--spawn-rate N] [--run-time 5m] [--master-host HOST] [--host URL]
# Modes: ui (default), headless, master, worker

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
LOCUST_FILE="tests/timeline_retrieval/locust_background_traffic.py"

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

ALB_URL_RESOLVED=$(get_alb_from_terraform)
echo "Using ALB URL: $ALB_URL_RESOLVED"

exec locust -f locust_background_traffic.py \
  --headless \
  --users 100 \
  --spawn-rate 50 \
  --run-time 15m \
  --host "$ALB_URL_RESOLVED"
