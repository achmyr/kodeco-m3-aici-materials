#!/usr/bin/env bash
# Build the review prompt used by Copilot, Claude Code, and Codex.
#
# Shared criteria live in CODE_REVIEW.md (repo root). This script adds only the
# runner-specific framing (what to review + how to inspect changes).
#
# Usage:
#   ./scripts/build-review-prompt.sh copilot <path-to-file>
#   ./scripts/build-review-prompt.sh codex [base-ref]
#   ./scripts/build-review-prompt.sh claude [base-ref] [repo] [pr-number]
#
# Prints the full prompt to stdout.
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
REPO_ROOT=$(cd "$SCRIPT_DIR/.." && pwd)
CRITERIA_FILE="$REPO_ROOT/CODE_REVIEW.md"

if [[ ! -f "$CRITERIA_FILE" ]]; then
  echo "error: missing shared criteria file: $CRITERIA_FILE" >&2
  exit 1
fi

MODE="${1:-}"
shift || true

case "$MODE" in
  copilot)
    FILE="${1:-}"
    if [[ -z "$FILE" ]]; then
      echo "usage: $0 copilot <path-to-file>" >&2
      exit 1
    fi
    cat <<EOF
Review @$FILE for this iOS project using the criteria in CODE_REVIEW.md below.

$(cat "$CRITERIA_FILE")
EOF
    ;;
  codex)
    BASE_REF="${1:-main}"
    cat <<EOF
Review this iOS pull request using the criteria in CODE_REVIEW.md below.

Inspect the changes with git when helpful (e.g. \`git diff origin/${BASE_REF}...HEAD\`).

$(cat "$CRITERIA_FILE")
EOF
    ;;
  claude)
    BASE_REF="${1:-main}"
    REPO="${2:-}"
    PR_NUMBER="${3:-}"
    cat <<EOF
REPO: ${REPO}
PR NUMBER: ${PR_NUMBER}
BASE: ${BASE_REF}

Goal: produce a concise PR review as your final message (posted as a PR comment).

1. Run once: \`git diff origin/${BASE_REF}...HEAD\`
2. Apply the CODE_REVIEW.md criteria below (included in full — no need to re-read the file).
3. Open individual files only when the diff is insufficient to judge an issue.
4. Finish with the full markdown review — no extra tool calls after that.

Do not explore the whole repo.

$(cat "$CRITERIA_FILE")
EOF
    ;;
  *)
    echo "usage: $0 {copilot <file>|codex [base]|claude [base] [repo] [pr]}" >&2
    exit 1
    ;;
esac
