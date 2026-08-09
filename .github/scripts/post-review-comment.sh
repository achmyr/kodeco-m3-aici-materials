#!/usr/bin/env bash
# Post an AI review markdown file as a GitHub pull-request comment.
#
# Used by AI review workflows under .github/workflows/.
#
# Usage:
#   .github/scripts/post-review-comment.sh <review-file> [heading]
#
# Environment:
#   GH_TOKEN or GITHUB_TOKEN   required (Actions provides GITHUB_TOKEN)
#   PR_NUMBER                  optional; inferred from $GITHUB_EVENT_PATH
#   GITHUB_REPOSITORY          owner/repo (Actions provides this)
#   MIN_BODY_LENGTH            default 100; skip posting if body is shorter
#
# Exit codes:
#   0  comment posted, or soft-skip (missing/short body)
#   1  hard failure (missing deps, auth, or API error)
set -euo pipefail

FILE="${1:-}"
HEADING="${2:-}"
MIN_BODY_LENGTH="${MIN_BODY_LENGTH:-100}"

if [[ -z "$FILE" ]]; then
  echo "usage: $0 <review-file> [heading]" >&2
  exit 1
fi

if [[ ! -f "$FILE" ]]; then
  echo "post-review-comment: missing review file '$FILE' – skipping comment" >&2
  exit 0
fi

if ! command -v gh >/dev/null 2>&1; then
  echo "error: 'gh' CLI is required to post the PR comment" >&2
  exit 1
fi

export GH_TOKEN="${GH_TOKEN:-${GITHUB_TOKEN:-}}"
if [[ -z "$GH_TOKEN" ]]; then
  echo "error: GH_TOKEN or GITHUB_TOKEN must be set" >&2
  exit 1
fi

if [[ -z "${PR_NUMBER:-}" && -n "${GITHUB_EVENT_PATH:-}" && -f "${GITHUB_EVENT_PATH}" ]]; then
  if command -v jq >/dev/null 2>&1; then
    PR_NUMBER=$(jq -r '.pull_request.number // .issue.number // empty' "$GITHUB_EVENT_PATH")
  fi
fi

if [[ -z "${PR_NUMBER:-}" ]]; then
  echo "error: PR_NUMBER is unset and could not be inferred from GITHUB_EVENT_PATH" >&2
  exit 1
fi

# Portable trim: strip CR, trailing spaces per line, and leading/trailing blank lines.
BODY=$(tr -d '\r' < "$FILE" | awk '
  {
    sub(/[[:space:]]+$/, "")
    lines[NR] = $0
  }
  END {
    start = 1
    while (start <= NR && lines[start] == "") start++
    end = NR
    while (end >= start && lines[end] == "") end--
    for (i = start; i <= end; i++) print lines[i]
  }
')

if [[ -z "$BODY" ]]; then
  echo "post-review-comment: empty review body – skipping comment" >&2
  exit 0
fi

if [[ -n "$HEADING" ]]; then
  first_line=$(printf '%s\n' "$BODY" | head -n 1)
  if [[ "$first_line" != "## $HEADING" && "$first_line" != "# $HEADING" ]]; then
    BODY="## ${HEADING}"$'\n\n'"${BODY}"
  fi
fi

body_len=${#BODY}
if (( body_len < MIN_BODY_LENGTH )); then
  echo "post-review-comment: review body too short (${body_len} < ${MIN_BODY_LENGTH}) – skipping comment" >&2
  exit 0
fi

TMP_BODY=$(mktemp)
trap 'rm -f "$TMP_BODY"' EXIT
printf '%s\n' "$BODY" > "$TMP_BODY"

echo "post-review-comment: posting ${body_len}-char comment on PR #${PR_NUMBER}"
gh pr comment "$PR_NUMBER" --body-file "$TMP_BODY"
echo "post-review-comment: done"
