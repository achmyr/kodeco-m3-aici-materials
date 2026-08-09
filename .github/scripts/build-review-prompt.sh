#!/usr/bin/env bash
# Build the review prompt used by Copilot, Claude Code, and Codex workflows.
#
# Shared criteria live in CODE_REVIEW.md (repo root). This script adds only the
# runner-specific framing (what to review + how to inspect changes).
#
# Usage (CI):
#   .github/scripts/build-review-prompt.sh copilot <base-ref>
#   .github/scripts/build-review-prompt.sh codex <base-ref>
#   .github/scripts/build-review-prompt.sh claude <base-ref> <repo> <pr-number>
#
# Prints the full prompt to stdout.
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
REPO_ROOT=$(cd "$SCRIPT_DIR/../.." && pwd)
CRITERIA_FILE="$REPO_ROOT/CODE_REVIEW.md"

if [[ ! -f "$CRITERIA_FILE" ]]; then
  echo "error: missing shared criteria file: $CRITERIA_FILE" >&2
  exit 1
fi

MODE="${1:-}"
shift || true

case "$MODE" in
  copilot)
    BASE_REF="${1:?usage: $0 copilot <base-ref>}"
    cat <<EOF
Review this iOS pull request using the criteria in CODE_REVIEW.md below.

1. Inspect the full change set once with: \`git diff origin/${BASE_REF}...HEAD\`
2. Open individual files only when the diff is insufficient to judge an issue.
3. Produce one concise whole-PR review (not a per-file report).
4. List only concrete high-severity issues with file:line references.

Do not explore the whole repo beyond the diff.

$(cat "$CRITERIA_FILE")
EOF
    ;;
  codex)
    BASE_REF="${1:?usage: $0 codex <base-ref>}"
    cat <<EOF
Review this iOS pull request using the criteria in CODE_REVIEW.md below.

Inspect the full change set once with git when helpful (e.g. \`git diff origin/${BASE_REF}...HEAD\`).
Produce one concise whole-PR review (not a per-file report).

$(cat "$CRITERIA_FILE")
EOF
    ;;
  claude)
    BASE_REF="${1:?usage: $0 claude <base-ref> <repo> <pr-number>}"
    REPO="${2:?usage: $0 claude <base-ref> <repo> <pr-number>}"
    PR_NUMBER="${3:?usage: $0 claude <base-ref> <repo> <pr-number>}"
    cat <<EOF
REPO: ${REPO}
PR NUMBER: ${PR_NUMBER}
BASE: ${BASE_REF}

Goal: produce a concise whole-PR review as your final message (posted as a PR comment).

1. Run once: \`git diff origin/${BASE_REF}...HEAD\`
2. Apply the CODE_REVIEW.md criteria below (included in full — no need to re-read the file).
3. Open individual files only when the diff is insufficient to judge an issue.
4. Finish with the full markdown review — no extra tool calls after that.
5. Do not write a per-file report; one issue list for the whole PR.

Do not explore the whole repo.

$(cat "$CRITERIA_FILE")
EOF
    ;;
  *)
    echo "usage: $0 {copilot|codex|claude} <base-ref> [repo] [pr]" >&2
    exit 1
    ;;
esac
