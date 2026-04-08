#!/usr/bin/env bash

set -euo pipefail

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
CSV_FILE="${1:-}"                                     # Target CSV (first arg)
DIR="/home/cdc/csvlogger/"
LOG="${DIR}/logs"
SNAPSHOT="${DIR}/snapshots"
SEPARATOR="|"                                         # Log field separator

# ---------------------------------------------------------------------------
# Validate input
# ---------------------------------------------------------------------------
if [[ -z "$CSV_FILE" ]]; then
  echo "ERROR: No CSV file specified."
  echo "Usage: $0 /path/to/file.csv"
  exit 1
fi

if [[ ! -f "$CSV_FILE" ]]; then
  echo "ERROR: File not found: $CSV_FILE"
  exit 1
fi

# ---------------------------------------------------------------------------
# Setup directories & derive names from the CSV filename
# ---------------------------------------------------------------------------
mkdir -p "$LOG" "$SNAPSHOT"

CSV_BASENAME="$(basename "$CSV_FILE" .csv)"
SNAPSHOT_FILE="${SNAPSHOT}/${CSV_BASENAME}.snapshot"
LOG_FILE="${LOG}/${CSV_BASENAME}_changes.log"
HEADER_FILE="${SNAPSHOT}/${CSV_BASENAME}.header"

TIMESTAMP="$(date '+%Y-%m-%d %H:%M:%S')"
USER="$(whoami)"
HOSTNAME="$(hostname)"

# ---------------------------------------------------------------------------
# Write log header if the log file is new
# ---------------------------------------------------------------------------
if [[ ! -f "$LOG_FILE" ]]; then
  {
    echo "# =============================================================="
    echo "# CSV Change Log"
    echo "# File    : $CSV_FILE"
    echo "# Created : $TIMESTAMP"
    echo "# Host    : $HOSTNAME"
    echo "# =============================================================="
    echo "# Fields  : TIMESTAMP${SEPARATOR}EVENT${SEPARATOR}USER${SEPARATOR}HOST${SEPARATOR}ROW_NUMBER${SEPARATOR}CHANGE_TYPE${SEPARATOR}COLUMN_AFFECTED${SEPARATOR}OLD_VALUE${SEPARATOR}NEW_VALUE${SEPARATOR}FULL_ROW"
    echo ""
  } > "$LOG_FILE"
fi

# ---------------------------------------------------------------------------
# Helper - write one structured log entry
# ---------------------------------------------------------------------------
log_entry() {
  local event="$1"        # ADDED | REMOVED | MODIFIED | FILE_CREATED | FILE_DELETED
  local row_num="$2"      # Row number in the CSV (1-based, including header)
  local change_type="$3"  # column-level: CELL_CHANGED | ROW_ADDED | ROW_REMOVED | N/A
  local col_name="$4"     # Column header name or N/A
  local old_val="$5"      # Previous value or N/A
  local new_val="$6"      # New value or N/A
  local full_row="$7"     # Full row contents

  echo "${TIMESTAMP}${SEPARATOR}${event}${SEPARATOR}${USER}${SEPARATOR}${HOSTNAME}${SEPARATOR}${row_num}${SEPARATOR}${change_type}${SEPARATOR}${col_name}${SEPARATOR}${old_val}${SEPARATOR}${new_val}${SEPARATOR}${full_row}" \
    >> "$LOG_FILE"
}

# ---------------------------------------------------------------------------
# First-run: no snapshot yet - capture baseline and exit
# ---------------------------------------------------------------------------
if [[ ! -f "$SNAPSHOT_FILE" ]]; then
  cp "$CSV_FILE" "$SNAPSHOT_FILE"
  # Save the header row for column-name lookup
  head -n 1 "$CSV_FILE" > "$HEADER_FILE"
  log_entry "FILE_CREATED" "N/A" "INITIAL_SNAPSHOT" "N/A" "N/A" "N/A" "Baseline snapshot created"
  echo "[$TIMESTAMP] Baseline snapshot saved. Future runs will detect changes."
  exit 0
fi

# ---------------------------------------------------------------------------
# Read header columns into an array
# ---------------------------------------------------------------------------
IFS=',' read -ra HEADERS < "$HEADER_FILE"
NUM_COLS="${#HEADERS[@]}"

# ---------------------------------------------------------------------------
# Helper - get the Nth comma-separated field from a row (1-based)
# ---------------------------------------------------------------------------
get_field() {
  local row="$1"
  local idx="$2"
  echo "$row" | cut -d',' -f"$idx"
}

# ---------------------------------------------------------------------------
# Diff old snapshot vs new file
# The diff output lines are prefixed with:
#   < = old (removed/changed from snapshot)
#   > = new (added/changed in current file)
# ---------------------------------------------------------------------------
DIFF_OUTPUT="$(diff --unchanged-line-format="" \
                    --old-line-format="OLD:%dn:%L" \
                    --new-line-format="NEW:%dn:%L" \
                    "$SNAPSHOT_FILE" "$CSV_FILE" 2>/dev/null || true)"

if [[ -z "$DIFF_OUTPUT" ]]; then
  echo "[$TIMESTAMP] No changes detected in: $CSV_FILE"
  exit 0
fi

echo "[$TIMESTAMP] Changes detected - writing to log: $LOG_FILE"

# ---------------------------------------------------------------------------
# Parse the diff output.
# Strategy: collect all OLD and NEW lines, then pair them by line number.
# If a line number appears in both OLD and NEW -> MODIFIED
# If only in OLD -> REMOVED
# If only in NEW -> ADDED
# ---------------------------------------------------------------------------
declare -A OLD_LINES   # old_lines[linenum] = content
declare -A NEW_LINES   # new_lines[linenum] = content

while IFS= read -r diff_line; do
  if [[ "$diff_line" =~ ^OLD:([0-9]+):(.*)$ ]]; then
    OLD_LINES["${BASH_REMATCH[1]}"]="${BASH_REMATCH[2]}"
  elif [[ "$diff_line" =~ ^NEW:([0-9]+):(.*)$ ]]; then
    NEW_LINES["${BASH_REMATCH[1]}"]="${BASH_REMATCH[2]}"
  fi
done <<< "$DIFF_OUTPUT"

# Collect all unique line numbers
declare -A ALL_LINES
for k in "${!OLD_LINES[@]}"; do ALL_LINES["$k"]=1; done
for k in "${!NEW_LINES[@]}"; do ALL_LINES["$k"]=1; done

# ---------------------------------------------------------------------------
# Process each changed line number
# ---------------------------------------------------------------------------
for line_num in $(echo "${!ALL_LINES[@]}" | tr ' ' '\n' | sort -n); do
  old_row="${OLD_LINES[$line_num]:-}"
  new_row="${NEW_LINES[$line_num]:-}"

  # Trim trailing newlines
  old_row="${old_row%$'\n'}"
  new_row="${new_row%$'\n'}"

  if [[ -n "$old_row" && -z "$new_row" ]]; then
    # Row was removed
    log_entry "REMOVED" "$line_num" "ROW_REMOVED" "N/A" "$old_row" "N/A" "$old_row"

  elif [[ -z "$old_row" && -n "$new_row" ]]; then
    # Row was added
    log_entry "ADDED" "$line_num" "ROW_ADDED" "N/A" "N/A" "$new_row" "$new_row"

  else
    # Row was modified - find which columns changed
    changed_any=false
    for (( col=1; col<=NUM_COLS; col++ )); do
      old_val="$(get_field "$old_row" "$col")"
      new_val="$(get_field "$new_row" "$col")"
      col_name="${HEADERS[$((col-1))]:-col_$col}"
      # Strip surrounding whitespace from header name
      col_name="$(echo "$col_name" | xargs)"

      if [[ "$old_val" != "$new_val" ]]; then
        log_entry "MODIFIED" "$line_num" "CELL_CHANGED" "$col_name" "$old_val" "$new_val" "$new_row"
        changed_any=true
      fi
    done

    # Fallback if column count mismatched
    if [[ "$changed_any" == false ]]; then
      log_entry "MODIFIED" "$line_num" "ROW_CHANGED" "N/A" "$old_row" "$new_row" "$new_row"
    fi
  fi
done

# ---------------------------------------------------------------------------
# Check for truncation / file shrinkage beyond diff (e.g. file deleted lines)
# ---------------------------------------------------------------------------
OLD_LINES_COUNT="$(wc -l < "$SNAPSHOT_FILE")"
NEW_LINES_COUNT="$(wc -l < "$CSV_FILE")"
if (( NEW_LINES_COUNT < OLD_LINES_COUNT )); then
  delta=$(( OLD_LINES_COUNT - NEW_LINES_COUNT ))
  echo "[$TIMESTAMP] NOTE: File shrank by $delta lines (possible bulk delete)."
fi

# ---------------------------------------------------------------------------
# Update snapshot to current state
# ---------------------------------------------------------------------------
cp "$CSV_FILE" "$SNAPSHOT_FILE"
head -n 1 "$CSV_FILE" > "$HEADER_FILE"

echo "[$TIMESTAMP] Snapshot updated. Log: $LOG_FILE"