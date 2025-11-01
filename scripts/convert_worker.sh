#!/usr/bin/env bash
# Worker que convierte archivos en lote con:
# - bloqueo (flock) para evitar concurrencia
# - timeout por conversión
# - logs en ./logs/convert.log
# - validación de archivos en input

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INPUT_DIR="${1:-$ROOT_DIR/input}"
OUTPUT_DIR="${2:-$ROOT_DIR/output}"
PROCESSED_DIR="${3:-$ROOT_DIR/processed}"
LOG_DIR="${4:-$ROOT_DIR/logs}"
LOCK_FILE="${5:-$ROOT_DIR/.convert_lock}"
TIMEOUT_SECONDS="${6:-300}"

mkdir -p "$INPUT_DIR" "$OUTPUT_DIR" "$PROCESSED_DIR" "$LOG_DIR"

# Diagnostic header
{
  echo "$(date -Iseconds) - Invoked: $0 $*"
  echo "$(date -Iseconds) - PID: $$, user: $(whoami), cwd: $(pwd)"
  echo "$(date -Iseconds) - PATH=$PATH"
} >> "$LOG_DIR/convert.log"

exec 200>"$LOCK_FILE"
# Wait up to 10s for lock to avoid transient races
if ! flock -w 10 200; then
  echo "$(date -Iseconds) - Another conversion is running; exiting after wait." >> "$LOG_DIR/convert.log"
  200>&-
  exit 0
fi
trap '200>&- || true' EXIT

shopt -s nullglob nocaseglob || true
converted=0
for f in "$INPUT_DIR"/*; do
  [ -f "$f" ] || continue

  lowercase="${f,,}"
  case "$lowercase" in
    *.pdf) target_ext=docx ;;
    *.docx|*.rtf|*.odt|*.txt|*.md) target_ext=pdf ;;
    *) echo "$(date -Iseconds) - Skipping unsupported: $f" >> "$LOG_DIR/convert.log"; continue ;;
  esac

  fname="$(basename -- "$f")"
  echo "$(date -Iseconds) - Converting '$fname' -> $target_ext" >> "$LOG_DIR/convert.log"

  if timeout "${TIMEOUT_SECONDS}s" soffice --headless --convert-to "$target_ext" --outdir "$OUTPUT_DIR" "$f" >> "$LOG_DIR/convert.log" 2>&1; then
    if mv -f -- "$f" "$PROCESSED_DIR"/; then
      echo "$(date -Iseconds) - Converted and moved: $fname" >> "$LOG_DIR/convert.log"
    else
      echo "$(date -Iseconds) - Converted but failed to move original: $fname" >> "$LOG_DIR/convert.log"
    fi
    converted=$((converted+1))
  else
    echo "$(date -Iseconds) - Conversion failed or timed out for: $fname" >> "$LOG_DIR/convert.log"
    mkdir -p "$ROOT_DIR/failed"
    mv -f -- "$f" "$ROOT_DIR/failed/" || true
  fi
done

echo "$(date -Iseconds) - Converted $converted files. Outputs in: $OUTPUT_DIR" >> "$LOG_DIR/convert.log"

exit 0
