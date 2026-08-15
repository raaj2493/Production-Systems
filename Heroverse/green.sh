#!/usr/bin/env bash
# green.sh — backfill a git repo's contribution graph with backdated commits.
#
# USAGE:
#   ./green.sh [START_DATE] [END_DATE] [MIN_COMMITS] [MAX_COMMITS] [REPO_DIR] [TARGET_FILE]
#
# EXAMPLE:
#   ./green.sh 2025-01-01 2025-06-30 1 5 . contributions.log
#
# All args are optional — edit the defaults below if you'd rather not pass CLI args.

set -euo pipefail

# ---------------- CONFIG (defaults, overridden by CLI args) ----------------
START_DATE="${1:-2025-01-01}"
END_DATE="${2:-2025-06-30}"
MIN_COMMITS="${3:-1}"
MAX_COMMITS="${4:-5}"
REPO_DIR="${5:-.}"
TARGET_FILE="${6:-contributions.log}"
SKIP_WEEKENDS=false          # set true if you want Sat/Sun to stay empty
COMMIT_MSG_PREFIX="update"
# -----------------------------------------------------------------------------

if [ "$MIN_COMMITS" -gt "$MAX_COMMITS" ]; then
  echo "Error: MIN_COMMITS ($MIN_COMMITS) cannot exceed MAX_COMMITS ($MAX_COMMITS)."
  exit 1
fi

cd "$REPO_DIR"

if [ ! -d .git ]; then
  echo "Error: '$REPO_DIR' is not a git repository (no .git folder found)."
  exit 1
fi

# Detect GNU date (Linux) vs BSD date (macOS) so the script works on both.
if date -d "$START_DATE" >/dev/null 2>&1; then
  IS_GNU_DATE=true
else
  IS_GNU_DATE=false
fi

add_days() {
  local base_date=$1
  local days=$2
  if $IS_GNU_DATE; then
    date -d "$base_date + $days days" +%Y-%m-%d
  else
    date -j -v+"${days}"d -f "%Y-%m-%d" "$base_date" +%Y-%m-%d
  fi
}

day_of_week() {
  local d=$1
  if $IS_GNU_DATE; then
    date -d "$d" +%u   # 1=Mon ... 7=Sun
  else
    date -j -f "%Y-%m-%d" "$d" +%u
  fi
}

current_date="$START_DATE"
total_commits=0

while [[ "$current_date" < "$END_DATE" || "$current_date" == "$END_DATE" ]]; do

  if $SKIP_WEEKENDS; then
    dow=$(day_of_week "$current_date")
    if [ "$dow" -ge 6 ]; then
      current_date=$(add_days "$current_date" 1)
      continue
    fi
  fi

  num_commits=$(( RANDOM % (MAX_COMMITS - MIN_COMMITS + 1) + MIN_COMMITS ))

  for ((i = 1; i <= num_commits; i++)); do
    hour=$(( RANDOM % 12 + 9 ))     # spread commits between 9am–9pm
    minute=$(( RANDOM % 60 ))
    second=$(( RANDOM % 60 ))
    commit_time=$(printf "%sT%02d:%02d:%02d" "$current_date" "$hour" "$minute" "$second")

    echo "$commit_time — entry $i" >> "$TARGET_FILE"
    git add "$TARGET_FILE"
    GIT_AUTHOR_DATE="$commit_time" GIT_COMMITTER_DATE="$commit_time" \
      git commit -m "$COMMIT_MSG_PREFIX: $current_date (#$i)" --quiet
    total_commits=$((total_commits + 1))
  done

  echo "$current_date: $num_commits commit(s)"
  current_date=$(add_days "$current_date" 1)
done

echo ""
echo "Done. $total_commits commits created from $START_DATE to $END_DATE."
echo "Review with: git log --oneline"
echo "Push with:   git push origin <branch>"