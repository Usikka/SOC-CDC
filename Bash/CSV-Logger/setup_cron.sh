#!/usr/bin/env bash
# =============================================================================
# setup_cron.sh - Installs a cron job to run csv_monitor.sh every 5 minutes
#
# USAGE:
#   ./setup_cron.sh /path/to/your/file.csv [interval_minutes]
#
# EXAMPLES:
#   ./setup_cron.sh /data/sales.csv          # runs every 5 mins (default)
#   ./setup_cron.sh /data/sales.csv 10       # runs every 10 mins
# =============================================================================

set -euo pipefail

CSV_FILE="${1:-}"
INTERVAL="${2:-5}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MONITOR_SCRIPT="${SCRIPT_DIR}/csv_monitor.sh"

# ---------------------------------------------------------------------------
# Validate
# ---------------------------------------------------------------------------
if [[ -z "$CSV_FILE" ]]; then
  echo "ERROR: Please provide the path to your CSV file."
  echo "Usage: $0 /path/to/file.csv [interval_minutes]"
  exit 1
fi

CSV_FILE="$(realpath "$CSV_FILE")"   # convert to absolute path

if [[ ! -f "$CSV_FILE" ]]; then
  echo "ERROR: CSV file not found: $CSV_FILE"
  exit 1
fi

if [[ ! -f "$MONITOR_SCRIPT" ]]; then
  echo "ERROR: Monitor script not found: $MONITOR_SCRIPT"
  echo "Make sure csv_monitor.sh is in the same directory as this script."
  exit 1
fi

# Ensure the monitor script is executable
chmod +x "$MONITOR_SCRIPT"

# ---------------------------------------------------------------------------
# Build cron expression
# ---------------------------------------------------------------------------
if (( INTERVAL < 1 || INTERVAL > 59 )); then
  echo "ERROR: Interval must be between 1 and 59 minutes."
  exit 1
fi

CRON_EXPR="*/${INTERVAL} * * * *"
CRON_JOB="${CRON_EXPR} ${MONITOR_SCRIPT} ${CSV_FILE} >> ${SCRIPT_DIR}/logs/cron.log 2>&1"

# ---------------------------------------------------------------------------
# Install cron job (avoid duplicates)
# ---------------------------------------------------------------------------
EXISTING_CRON="$(crontab -l 2>/dev/null || true)"

if echo "$EXISTING_CRON" | grep -qF "$MONITOR_SCRIPT"; then
  echo "A cron job for csv_monitor.sh already exists."
  echo ""
  echo "Current crontab entries for this script:"
  echo "$EXISTING_CRON" | grep "$MONITOR_SCRIPT"
  echo ""
  read -rp "Do you want to replace it? [y/N]: " confirm
  if [[ "${confirm,,}" != "y" ]]; then
    echo "Aborted. No changes made."
    exit 0
  fi
  # Remove old entry
  EXISTING_CRON="$(echo "$EXISTING_CRON" | grep -v "$MONITOR_SCRIPT")"
fi

# Write new crontab
{
  echo "$EXISTING_CRON"
  echo "$CRON_JOB"
} | crontab -

echo ""
echo "Cron job installed successfully!"
echo ""
echo "  Schedule : every ${INTERVAL} minute(s)"
echo "  CSV file : $CSV_FILE"
echo "  Script   : $MONITOR_SCRIPT"
echo "  Cron log : ${SCRIPT_DIR}/logs/cron.log"
echo "  Change log: ${SCRIPT_DIR}/logs/$(basename "$CSV_FILE" .csv)_changes.log"
echo ""
echo "Running initial baseline snapshot now..."
"$MONITOR_SCRIPT" "$CSV_FILE"
echo ""
echo "Done. Changes will be logged starting from the next scheduled run."
echo ""
echo "To view logs:      tail -f ${SCRIPT_DIR}/logs/$(basename "$CSV_FILE" .csv)_changes.log"
echo "To remove the job: crontab -e  (then delete the csv_monitor line)"
