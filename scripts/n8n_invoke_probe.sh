#!/usr/bin/env bash
# Probe wrapper: logs environment and launches worker in background when invoked by n8n
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_DIR="${1:-$ROOT_DIR/logs}"
LOCK_FILE="${2:-$ROOT_DIR/.convert_lock}"
TIMEOUT_SECONDS="${3:-300}"

mkdir -p "$LOG_DIR"
OUTFILE="$LOG_DIR/exec_node.log"

TS=$(date -Iseconds)
PID=$$

{
  echo "$TS - n8n probe invoked"
  echo "TS=$TS PID=$PID USER=$(whoami) PWD=$(pwd)"
  echo "ARGS=$*"
  echo "PATH=$PATH"
  echo "LOG_DIR=$LOG_DIR"
} >> "$OUTFILE" 2>&1

touch "$LOG_DIR/n8n_probe_$(date +%s).ok" || true

# Launch the real worker in background and log its output
nohup "$ROOT_DIR/scripts/convert_worker.sh" "$ROOT_DIR/input" "$ROOT_DIR/output" "$ROOT_DIR/processed" "$LOG_DIR" "$TIMEOUT_SECONDS" >> "$OUTFILE" 2>&1 &

echo "Started worker in background (probe) at $(date -Iseconds)" >> "$OUTFILE"

exit 0
