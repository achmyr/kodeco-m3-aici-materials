#!/usr/bin/env bash
# AI code review for Swift/Objective-C changes, using the GitHub Copilot CLI
# and the project's CODE_REVIEW.md guidance.
#
# Used by .github/workflows/ai-code-review.yml (--ci mode, PR diff) and
# interactively by developers (default/--base/--staged modes, local diff).
#
# Captures per-call token usage via the Copilot CLI's OTel file exporter,
# since `--silent` (used to keep the review output clean) suppresses the
# CLI's normal "Tokens ↑/↓" summary. When $GITHUB_STEP_SUMMARY is set (i.e.
# running inside a GitHub Actions job), the token summary is also appended
# there as a markdown table.
#
# Usage:
#   ./scripts/ai-code-review.sh                 # review uncommitted changes vs HEAD
#   ./scripts/ai-code-review.sh --base main      # review current branch vs another ref
#   ./scripts/ai-code-review.sh --staged         # review staged changes only
#   ./scripts/ai-code-review.sh --ci <base-ref>  # review origin/<base-ref>...HEAD (used by CI)
#
# Options:
#   --review-file <path>  Where to write the markdown review (default: review.md)
#   --otel-file <path>    Where to write raw OTel JSONL (default: temp file)
set -euo pipefail

MODE="local"
BASE_REF="HEAD"
STAGED_ONLY=false
REVIEW_FILE="review.md"
OTEL_FILE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --ci)
      MODE="ci"
      BASE_REF="$2"
      shift 2
      ;;
    --base)
      MODE="local"
      BASE_REF="$2"
      shift 2
      ;;
    --staged)
      STAGED_ONLY=true
      shift
      ;;
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
    *)
      echo "Unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

if ! command -v copilot >/dev/null 2>&1; then
  echo "error: 'copilot' CLI not found. Install with: npm install -g @github/copilot" >&2
  exit 1
fi

REPO_ROOT=$(git rev-parse --show-toplevel)
cd "$REPO_ROOT"

CLEANUP_DIR=""
if [ -z "$OTEL_FILE" ]; then
  CLEANUP_DIR=$(mktemp -d)
  OTEL_FILE="$CLEANUP_DIR/copilot-otel.jsonl"
  trap 'rm -rf "$CLEANUP_DIR"' EXIT
fi

# --- Collect changed Swift/Obj-C files -------------------------------------
if [ "$MODE" = "ci" ]; then
  # Three-dot diff: PR branch vs the merge-base with the target branch.
  FILES=$(git diff --name-only "origin/$BASE_REF"...HEAD -- '*.swift' '*.m' '*.h' '*.mm' || true)
elif $STAGED_ONLY; then
  FILES=$(git diff --name-only --cached -- '*.swift' '*.m' '*.h' '*.mm' || true)
else
  # Tracked changes (staged + unstaged) vs $BASE_REF, plus new untracked files.
  TRACKED=$(git diff --name-only "$BASE_REF" -- '*.swift' '*.m' '*.h' '*.mm' || true)
  UNTRACKED=$(git ls-files --others --exclude-standard -- '*.swift' '*.m' '*.h' '*.mm' || true)
  FILES=$(printf '%s\n%s\n' "$TRACKED" "$UNTRACKED" | sed '/^$/d' | sort -u)
fi

if [ -z "$FILES" ]; then
  echo "No Swift/Objective-C changes found – nothing to review."
  echo "# AI Code Review" > "$REVIEW_FILE"
  echo "" >> "$REVIEW_FILE"
  echo "No Swift/Objective-C changes found – nothing to review." >> "$REVIEW_FILE"
  exit 0
fi

echo "Reviewing changed files:"
printf '  %s\n' $FILES
echo

{
  echo "# AI Code Review"
  echo
  echo "Focus: correctness/safety, Swift concurrency, retain cycles, SwiftUI state, project conventions (see CODE_REVIEW.md)."
  echo
} > "$REVIEW_FILE"

# Shared criteria with Claude/Codex (CODE_REVIEW.md via build-review-prompt.sh).
BUILD_PROMPT="$(dirname "$0")/build-review-prompt.sh"
if [[ ! -x "$BUILD_PROMPT" ]]; then
  echo "error: missing $BUILD_PROMPT" >&2
  exit 1
fi

# --- Run the review ----------------------------------------------------------
export COPILOT_OTEL_ENABLED=true
export COPILOT_OTEL_EXPORTER_TYPE=file
export COPILOT_OTEL_FILE_EXPORTER_PATH="$OTEL_FILE"

for file in $FILES; do
  echo "## $file" >> "$REVIEW_FILE"
  PROMPT=$("$BUILD_PROMPT" copilot "$file")
  copilot -p "$PROMPT" \
    --allow-tool='shell(git:*)' --no-ask-user --silent >> "$REVIEW_FILE" 2>/dev/null || true
  echo >> "$REVIEW_FILE"
done

echo "=================================================================="
cat "$REVIEW_FILE"
echo "=================================================================="

# --- Token summary from the OTel file exporter ------------------------------
# Shared console + GitHub Step Summary layout (same as Claude/Codex scripts).
# shellcheck source=token-usage-summary.sh
source "$(dirname "$0")/token-usage-summary.sh"

if ! command -v jq >/dev/null 2>&1; then
  echo "  (jq not found - skipping token summary)" >&2
else
  TOTALS_JSONL=""
  CALLS=0
  if [ -s "$OTEL_FILE" ]; then
    # One JSON object per token type: {"key": "input", "value": <sum>}
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
fi

