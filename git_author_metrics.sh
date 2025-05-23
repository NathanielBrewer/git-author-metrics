#!/bin/bash

# Determine the directory where the script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}" .sh)"
LOG_FILE="${SCRIPT_DIR}/${SCRIPT_NAME}.log"

console_log() {
  echo "$1"
}

file_log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

console_and_file_log() {
  console_log "$1"
  file_log "$1"
}

# Check for arguments
if [ "$#" -lt 4 ]; then
  console_log "Usage: $0 <start-date-yyyy-mm-dd> <end-date-yyyy-mm-dd> <author-name> <repo_url_1> [repo_url_2 ... repo_url_N]" >&2
  exit 1
fi

# Assign arguments
START_DATE=$1
END_DATE=$2
AUTHOR=$3
shift 3  # Remove the first three arguments, leaving only the list of repositories
REPOS=("$@")

# Validate the date format
if ! [[ "$START_DATE" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] || ! [[ "$END_DATE" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
  console_and_file_log "Invalid date format error: START_DATE=$START_DATE, END_DATE=$END_DATE. Correct format is yyyy-mm-dd"
  exit 1
fi

# Initialize totals
TOTAL_ADDED=0
TOTAL_REMOVED=0
TOTAL_COMMITS=0
COMMIT_MESSAGE_LENGTHS=()

# Global array to track processed commits
declare -A PROCESSED_COMMITS

process_commit() {
  local commit_hash=$1
  local commit_message=$2

  # Skip already processed commits
  if [ "${PROCESSED_COMMITS[$commit_hash]}" ]; then
    return
  fi
  PROCESSED_COMMITS[$commit_hash]=1

  local stats
  stats=$(git show --numstat "$commit_hash" 2>> "$LOG_FILE")

  # Parse added and removed lines, filtering only numeric values
  local added
  added=$(echo "$stats" | awk '$1 ~ /^[0-9]+$/ && $2 ~ /^[0-9]+$/ {added += $1} END {print added}')
  local removed
  removed=$(echo "$stats" | awk '$1 ~ /^[0-9]+$/ && $2 ~ /^[0-9]+$/ {removed += $2} END {print removed}')

  # Default to 0 if values are empty
  added=${added:-0}
  removed=${removed:-0}

  # Update totals
  TOTAL_ADDED=$((TOTAL_ADDED + added))
  TOTAL_REMOVED=$((TOTAL_REMOVED + removed))
  TOTAL_COMMITS=$((TOTAL_COMMITS + 1))
  COMMIT_MESSAGE_LENGTHS+=(${#commit_message})
}

process_branch() {
  local branch=$1

  console_and_file_log "Processing branch: $branch"

  # Find commits by author in the date range
  local commits
  commits=$(git log "$branch" --author="$AUTHOR" --since="$START_DATE 00:00:00" --until="$END_DATE 23:59:59" --no-merges --pretty=format:"%H %s" 2>> "$LOG_FILE")
  
  if [ -z "$commits" ]; then
    file_log "No commits found for author '$AUTHOR' on branch '$branch'."
    return
  fi

  # Process each commit
  while read -r line; do
    local commit_hash
    commit_hash=$(echo "$line" | awk '{print $1}')
    local commit_message
    commit_message=$(echo "$line" | cut -d' ' -f2-)
    process_commit "$commit_hash" "$commit_message"
  done <<< "$commits"
}

extract_project_name() {
  local url="$1"
  # Remove everything up to the last ':' or '/' and then trim the .git suffix if present.
  local project="${url##*[:/]}"
  project="${project%.git}"

  if [ -z "$project" ]; then
    console_and_file_log "Error: Could not extract project name from URL '$url'. Exiting."
    exit 1
  fi

  echo "$project"
}

process_repository_url() {
  PROJECTS_DIR="/app/git-author-metrics/projects"
  if ! test -d "$PROJECTS_DIR"; then
    mkdir -p "$PROJECTS_DIR"
  fi
  cd "$PROJECTS_DIR" || { console_and_file_log "Failed to change directory to $PROJECTS_DIR"; return 1; }

  local repo_url="$1"
  local project_name
  project_name=$(extract_project_name "$repo_url")

  console_log "project_name='$project_name', repo_url='$repo_url'"

  if [ -d "$project_name" ]; then
    console_and_file_log "Repository '$project_name' already exists locally. No need to clone"
    cd "$project_name" || { console_and_file_log "Failed to enter project directory $project_name"; return 1; }
  else
    if ! git clone "$repo_url"; then
      console_and_file_log "Error: Failed to clone repository '$repo_url'."
      return 1
    fi
    cd "$project_name" || { console_and_file_log "Failed to enter project directory $project_name"; return 1; }
  fi

  git fetch --all > /dev/null 2>> "$LOG_FILE"
  git pull --all > /dev/null 2>> "$LOG_FILE"

  if [ $? -ne 0 ]; then
    console_and_file_log "Error: Failed to fetch branches in repository '$repo_url'."
    return 1
  fi

  local default_remote
  default_remote=$(git remote | grep -E "^origin$" || git remote | head -n1)
  if [ -z "$default_remote" ]; then
    console_and_file_log "Error: No remote found in repository."
    return 1
  fi

  # Get all branches for the current remote
  local branches
  branches=$(git branch -r | awk -v remote="$default_remote" '!/->/ && $1 ~ "^"remote"/" {sub("^"remote"/", ""); print}')

  # Process each branch
  for branch in $branches; do
    process_branch "$branch"
  done

  cd "$PROJECTS_DIR" || return 1
  cd .. || return 1
  rm -rf "$PROJECTS_DIR"
}

process_repository() {
  local repo_path=$1

  # Validate the repo path
  if [ ! -d "$repo_path" ] || [ ! -d "$repo_path/.git" ]; then
    console_and_file_log "Error: '$repo_path' is not a valid Git repository."
    return
  fi

  # Switch to the repository directory
  cd "$repo_path" || return

  # Fetch all remotes
  git fetch --all > /dev/null 2>> "$LOG_FILE"
  if [ $? -ne 0 ]; then
    console_and_file_log "Error: Failed to fetch branches in repository '$repo_path'."
    return
  fi

  local default_remote
  default_remote=$(git remote | grep -E "^origin$" || git remote | head -n1)
  if [ -z "$default_remote" ]; then
    console_and_file_log "Error: No remote found in repository."
    return
  fi

  # Get all branches for the current remote
  local branches
  branches=$(git branch -r | awk -v remote="$default_remote" '!/->/ && $1 ~ "^"remote"/" {sub("^"remote"/", ""); print}')

  # Process each branch
  for branch in $branches; do
    process_branch "$branch"
  done
}

# Process each repo
for repo in "${REPOS[@]}"; do
  process_repository_url "$repo"
done

# Calculate aggregate metrics
if [ ${#COMMIT_MESSAGE_LENGTHS[@]} -gt 0 ]; then
  MAX_LENGTH=$(printf "%s\n" "${COMMIT_MESSAGE_LENGTHS[@]}" | sort -nr | head -n1)
  MIN_LENGTH=$(printf "%s\n" "${COMMIT_MESSAGE_LENGTHS[@]}" | sort -n | head -n1)
  AVG_LENGTH=$(printf "%s\n" "${COMMIT_MESSAGE_LENGTHS[@]}" | awk '{sum+=$1} END {print sum/NR}')
else
  MAX_LENGTH=0
  MIN_LENGTH=0
  AVG_LENGTH=0
fi

# Build JSON output
JSON_OUTPUT=$(cat <<EOF
{
  "commits": $TOTAL_COMMITS,
  "averageMessageLength": $(printf "%.2f" "$AVG_LENGTH"),
  "maxMessageLength": $MAX_LENGTH,
  "minMessageLength": $MIN_LENGTH,
  "totalLinesAdded": $TOTAL_ADDED,
  "totalLinesRemoved": $TOTAL_REMOVED
}
EOF
)

# Print JSON output to stdout so that a Node.js caller can capture it
echo "$JSON_OUTPUT"
