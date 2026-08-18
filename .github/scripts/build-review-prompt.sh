#!/usr/bin/env bash
# Build the review prompt used by Copilot, Claude Code, and Codex workflows.
#
# Shared criteria live in CODE_REVIEW.md (repo root). CI-specific policy
# (how strictly to apply that file) lives in CI_GUIDANCE.md, passed by
# the workflow as --guidance or $CI_GUIDANCE.
#
# Usage (CI):
#   .github/scripts/build-review-prompt.sh copilot <base-ref> [--guidance path]
#   .github/scripts/build-review-prompt.sh codex <base-ref> [--guidance path]
#   .github/scripts/build-review-prompt.sh claude <base-ref> <repo> <pr-number> [--guidance path]
#
# Prints the full prompt to stdout.
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
REPO_ROOT=$(cd "$SCRIPT_DIR/../.." && pwd)
CRITERIA_FILE="$REPO_ROOT/CODE_REVIEW.md"
GUIDANCE_FILE="${CI_GUIDANCE:-}"

POSITIONAL=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --guidance)
      GUIDANCE_FILE="$2"
      shift 2
      ;;
    -h|--help)
      grep '^#' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    --*)
      echo "Unknown option: $1" >&2
      exit 1
      ;;
    *)
      POSITIONAL+=("$1")
      shift
      ;;
  esac
done
set -- "${POSITIONAL[@]+"${POSITIONAL[@]}"}"

if [[ ! -f "$CRITERIA_FILE" ]]; then
  echo "error: missing shared criteria file: $CRITERIA_FILE" >&2
  exit 1
fi

if [[ -z "$GUIDANCE_FILE" ]]; then
  GUIDANCE_FILE="$REPO_ROOT/CI_GUIDANCE.md"
elif [[ ! -f "$GUIDANCE_FILE" && -f "$REPO_ROOT/$GUIDANCE_FILE" ]]; then
  GUIDANCE_FILE="$REPO_ROOT/$GUIDANCE_FILE"
fi

if [[ ! -f "$GUIDANCE_FILE" ]]; then
  echo "error: missing CI guidance file: $GUIDANCE_FILE" >&2
  exit 1
fi

MODE="${1:-}"
shift || true

# Drop a leading/trailing blank line so an empty file inserts nothing.
GUIDANCE=$(sed -e '1{/^$/d;}' -e '${/^$/d;}' "$GUIDANCE_FILE")
CRITERIA=$(cat "$CRITERIA_FILE")

if [[ -n "$GUIDANCE" ]]; then
  GUIDANCE_BLOCK=$'\n'"${GUIDANCE}"$'\n'
else
  GUIDANCE_BLOCK=""
fi

case "$MODE" in
  copilot)
    BASE_REF="${1:?usage: $0 copilot <base-ref> [--guidance path]}"
    cat <<EOF
Review this iOS pull request using the criteria in CODE_REVIEW.md below.
${GUIDANCE_BLOCK}
1. Inspect the full change set once with: \`git diff origin/${BASE_REF}...HEAD\`
2. Open individual files only when the diff is insufficient to judge an issue.
3. Produce one concise whole-PR review (not a per-file report).
4. List only concrete high-severity issues with file:line references.

Do not explore the whole repo beyond the diff.

${CRITERIA}
EOF
    ;;
  codex)
    BASE_REF="${1:?usage: $0 codex <base-ref> [--guidance path]}"
    cat <<EOF
Review this iOS pull request using the criteria in CODE_REVIEW.md below.
${GUIDANCE_BLOCK}
Inspect the full change set once with git when helpful (e.g. \`git diff origin/${BASE_REF}...HEAD\`).
Produce one concise whole-PR review (not a per-file report).

${CRITERIA}
EOF
    ;;
  claude)
    BASE_REF="${1:?usage: $0 claude <base-ref> <repo> <pr-number> [--guidance path]}"
    REPO="${2:?usage: $0 claude <base-ref> <repo> <pr-number> [--guidance path]}"
    PR_NUMBER="${3:?usage: $0 claude <base-ref> <repo> <pr-number> [--guidance path]}"
    cat <<EOF
REPO: ${REPO}
PR NUMBER: ${PR_NUMBER}
BASE: ${BASE_REF}

Goal: produce a concise whole-PR review as your final message (posted as a PR comment).
${GUIDANCE_BLOCK}
1. Run once: \`git diff origin/${BASE_REF}...HEAD\`
2. Apply the CODE_REVIEW.md criteria below (included in full — no need to re-read the file).
3. Open individual files only when the diff is insufficient to judge an issue.
4. Finish with the full markdown review — no extra tool calls after that.
5. Do not write a per-file report; one issue list for the whole PR.

Do not explore the whole repo.

${CRITERIA}
EOF
    ;;
  *)
    echo "usage: $0 {copilot|codex|claude} <base-ref> [repo] [pr] [--guidance path]" >&2
    exit 1
    ;;
esac
