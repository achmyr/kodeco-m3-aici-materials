#!/usr/bin/env bash
# Whole-diff AI code review via GitHub Copilot CLI (CI only).
#
# Used by .github/workflows/ai-code-review.yml.
# Captures token usage via the Copilot OTel file exporter.
#
# Usage:
#   .github/scripts/ai-code-review.sh <base-ref> [--review-file path] [--otel-file path]
set -euo pipefail

BASE_REF=""
REVIEW_FILE="review.md"
OTEL_FILE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --review-file)
      REVIEW_FILE="$2"
      shift 2
      ;;
    --otel-file)
      OTEL_FILE="$2"
      shift 2
      ;;
    -h|--help)
      grep '^#' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    -*)
      echo "Unknown option: $1" >&2
      exit 1
      ;;
    *)
      if [[ -z "$BASE_REF" ]]; then
        BASE_REF="$1"
        shift
      else
        echo "Unexpected argument: $1" >&2
        exit 1
      fi
      ;;
  esac
done

if [[ -z "$BASE_REF" ]]; then
  echo "usage: $0 <base-ref> [--review-file path] [--otel-file path]" >&2
  exit 1
fi

if ! command -v copilot >/dev/null 2>&1; then
  echo "error: 'copilot' CLI not found. Install with: npm install -g @github/copilot" >&2
  exit 1
fi

REPO_ROOT=$(git rev-parse --show-toplevel)
cd "$REPO_ROOT"

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
BUILD_PROMPT="$SCRIPT_DIR/build-review-prompt.sh"

CLEANUP_DIR=""
if [[ -z "$OTEL_FILE" ]]; then
  CLEANUP_DIR=$(mktemp -d)
  OTEL_FILE="$CLEANUP_DIR/copilot-otel.jsonl"
  trap 'rm -rf "$CLEANUP_DIR"' EXIT
fi

DIFF_SPEC="origin/${BASE_REF}...HEAD"
FILES=$(git diff --name-only "$DIFF_SPEC" 2>/dev/null || true)

if [[ -z "$FILES" ]]; then
  echo "No changes found – nothing to review."
  echo "No changes found – nothing to review." > "$REVIEW_FILE"
  exit 0
fi

echo "Reviewing whole change set (${DIFF_SPEC}):"
printf '  %s\n' $FILES
echo

PROMPT=$("$BUILD_PROMPT" copilot "$BASE_REF")

export COPILOT_OTEL_ENABLED=true
export COPILOT_OTEL_EXPORTER_TYPE=file
export COPILOT_OTEL_FILE_EXPORTER_PATH="$OTEL_FILE"

# Write only the model output; post-review-comment.sh adds the section heading.
: > "$REVIEW_FILE"
if ! copilot -p "$PROMPT" \
  --allow-tool='shell(git:*)' --no-ask-user --silent >> "$REVIEW_FILE" 2>/dev/null; then
  echo "warning: copilot exited non-zero; review file may be incomplete" >&2
fi

if [[ ! -s "$REVIEW_FILE" ]]; then
  echo "warning: empty review output from copilot" >&2
fi

echo "=================================================================="
cat "$REVIEW_FILE"
echo "=================================================================="

# shellcheck source=token-usage-summary.sh
source "$SCRIPT_DIR/token-usage-summary.sh"

if ! command -v jq >/dev/null 2>&1; then
  echo "  (jq not found - skipping token summary)" >&2
  exit 0
fi

TOTALS_JSONL=""
CALLS=0
if [[ -s "$OTEL_FILE" ]]; then
  TOTALS_JSONL=$(jq -c '
    select(.type == "metric" and .name == "gen_ai.client.token.usage")
    | .dataPoints[]
    | {key: (.attributes["gen_ai.token.type"] // "unknown"), value: (.value.sum // 0)}
  ' "$OTEL_FILE" | jq -sc 'group_by(.key) | map({key: .[0].key, value: (map(.value) | add)}) | sort_by(.key) | .[]')

  CALLS=$(jq '
    select(.type == "metric" and .name == "gen_ai.client.token.usage")
    | .dataPoints[]
    | select(.attributes["gen_ai.token.type"] == "input")
    | (.value.count // 0)
  ' "$OTEL_FILE" | awk '{sum += $1} END {print sum + 0}')
fi

print_token_usage_summary "$TOTALS_JSONL" "$CALLS" "$OTEL_FILE"
