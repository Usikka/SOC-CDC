#!/usr/bin/env bash
# =============================================================================
# view_log.sh - Human-readable viewer and filter tool for CSV change logs
#
# USAGE:
#   ./view_log.sh <log_file> [options]
#
# OPTIONS:
#   --user USER        Filter by user who triggered the change
#   --event TYPE       Filter by event type: ADDED, REMOVED, MODIFIED, FILE_CREATED
#   --column COL       Filter by column name
#   --since DATETIME   Show entries after this datetime (format: "YYYY-MM-DD HH:MM:SS")
#   --tail N           Show last N entries (default: all)
#   --summary          Print a summary report instead of full log
#
# EXAMPLES:
#   ./view_log.sh logs/sales_changes.log
#   ./view_log.sh logs/sales_changes.log --user john --event MODIFIED
#   ./view_log.sh logs/sales_changes.log --column price --since "2024-01-15 09:00:00"
#   ./view_log.sh logs/sales_changes.log --summary
# =============================================================================

set -euo pipefail

LOG_FILE="${1:-}"
SEP="|"

if [[ -z "$LOG_FILE" || ! -f "$LOG_FILE" ]]; then
  echo "ERROR: Please provide a valid log file path."
  echo "Usage: $0 /path/to/log_file [options]"
  exit 1
fi

# ---------------------------------------------------------------------------
# Parse options
# ---------------------------------------------------------------------------
shift
FILTER_USER=""
FILTER_EVENT=""
FILTER_COLUMN=""
FILTER_SINCE=""
TAIL_N=""
SUMMARY=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --user)    FILTER_USER="$2";   shift 2 ;;
    --event)   FILTER_EVENT="$2";  shift 2 ;;
    --column)  FILTER_COLUMN="$2"; shift 2 ;;
    --since)   FILTER_SINCE="$2";  shift 2 ;;
    --tail)    TAIL_N="$2";        shift 2 ;;
    --summary) SUMMARY=true;       shift ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

# ---------------------------------------------------------------------------
# Read log entries (skip comment/header lines)
# ---------------------------------------------------------------------------
mapfile -t RAW_LINES < <(grep -v '^#' "$LOG_FILE" | grep -v '^$')

# ---------------------------------------------------------------------------
# Filter entries
# ---------------------------------------------------------------------------
FILTERED=()
for line in "${RAW_LINES[@]}"; do
  IFS="$SEP" read -ra FIELDS <<< "$line"
  # Fields: TIMESTAMP|EVENT|USER|HOST|ROW_NUMBER|CHANGE_TYPE|COLUMN_AFFECTED|OLD_VALUE|NEW_VALUE|FULL_ROW
  ts="${FIELDS[0]:-}"
  event="${FIELDS[1]:-}"
  user="${FIELDS[2]:-}"
  col="${FIELDS[6]:-}"

  [[ -n "$FILTER_USER"   && "$user"  != "$FILTER_USER"  ]] && continue
  [[ -n "$FILTER_EVENT"  && "$event" != "$FILTER_EVENT" ]] && continue
  [[ -n "$FILTER_COLUMN" && "$col"   != "$FILTER_COLUMN"]] && continue
  [[ -n "$FILTER_SINCE"  && "$ts"    <  "$FILTER_SINCE" ]] && continue

  FILTERED+=("$line")
done

# Apply tail
if [[ -n "$TAIL_N" ]]; then
  TOTAL="${#FILTERED[@]}"
  START=$(( TOTAL - TAIL_N ))
  (( START < 0 )) && START=0
  FILTERED=("${FILTERED[@]:$START}")
fi

# ---------------------------------------------------------------------------
# Summary mode
# ---------------------------------------------------------------------------
if [[ "$SUMMARY" == true ]]; then
  echo ""
  echo "========================================"
  echo "  CSV CHANGE LOG SUMMARY"
  echo "  File: $LOG_FILE"
  echo "  Entries shown: ${#FILTERED[@]}"
  echo "========================================"
  echo ""

  declare -A EVENT_COUNTS USER_COUNTS COL_COUNTS

  for line in "${FILTERED[@]}"; do
    IFS="$SEP" read -ra F <<< "$line"
    event="${F[1]:-UNKNOWN}";  EVENT_COUNTS["$event"]=$(( ${EVENT_COUNTS["$event"]:-0} + 1 ))
    user="${F[2]:-UNKNOWN}";   USER_COUNTS["$user"]=$(( ${USER_COUNTS["$user"]:-0} + 1 ))
    col="${F[6]:-N/A}";        COL_COUNTS["$col"]=$(( ${COL_COUNTS["$col"]:-0} + 1 ))
  done

  echo "  Changes by Event Type:"
  for k in "${!EVENT_COUNTS[@]}"; do printf "    %-20s %d\n" "$k" "${EVENT_COUNTS[$k]}"; done | sort

  echo ""
  echo "  Changes by User:"
  for k in "${!USER_COUNTS[@]}"; do printf "    %-20s %d\n" "$k" "${USER_COUNTS[$k]}"; done | sort

  echo ""
  echo "  Changes by Column:"
  for k in "${!COL_COUNTS[@]}"; do printf "    %-20s %d\n" "$k" "${COL_COUNTS[$k]}"; done | sort

  echo ""
  if [[ "${#FILTERED[@]}" -gt 0 ]]; then
    FIRST_TS="$(echo "${FILTERED[0]}" | cut -d"$SEP" -f1)"
    LAST_TS="$(echo "${FILTERED[-1]}" | cut -d"$SEP" -f1)"
    echo "  Date Range: $FIRST_TS  →  $LAST_TS"
  fi
  echo ""
  exit 0
fi

# ---------------------------------------------------------------------------
# Pretty-print mode
# ---------------------------------------------------------------------------
if [[ "${#FILTERED[@]}" -eq 0 ]]; then
  echo "No log entries match the given filters."
  exit 0
fi

echo ""
printf "%-20s %-10s %-15s %-10s %-6s %-15s %-15s %-20s %-20s\n" \
  "TIMESTAMP" "EVENT" "USER" "HOST" "ROW" "CHANGE_TYPE" "COLUMN" "OLD_VALUE" "NEW_VALUE"
printf '%s\n' "$(printf '%.0s-' {1..130})"

for line in "${FILTERED[@]}"; do
  IFS="$SEP" read -ra F <<< "$line"
  ts="${F[0]:-}"; event="${F[1]:-}"; user="${F[2]:-}"; host="${F[3]:-}"
  row="${F[4]:-}"; chtype="${F[5]:-}"; col="${F[6]:-}"; old="${F[7]:-}"; new="${F[8]:-}"

  printf "%-20s %-10s %-15s %-10s %-6s %-15s %-15s %-20s %-20s\n" \
    "$ts" "$event" "$user" "$host" "$row" "$chtype" "$col" \
    "${old:0:20}" "${new:0:20}"
done

echo ""
echo "Total entries: ${#FILTERED[@]}"
echo ""
