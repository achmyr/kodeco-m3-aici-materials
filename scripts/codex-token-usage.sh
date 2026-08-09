#!/usr/bin/env bash
# Print token usage from a Codex CLI session rollout (JSONL).
#
# Used by .github/workflows/codex-review.yml after openai/codex-action.
# Codex does not expose token counts as Action outputs. Instead it writes
# session rollouts under $CODEX_HOME/sessions/YYYY/MM/DD/rollout-*.jsonl.
# Each completed turn emits a line like:
#   {"type":"turn.completed","usage":{"input_tokens":…,"cached_input_tokens":…,
#    "output_tokens":…,"reasoning_output_tokens":…}}
# turn.completed.usage is cumulative for the session, so we take the *last*
# turn.completed event (not a sum of all turns).
#
# Console + GitHub Step Summary match scripts/ai-code-review.sh via
# scripts/token-usage-summary.sh.
#
# Usage:
#   ./scripts/codex-token-usage.sh                 # $CODEX_HOME or ~/.codex
#   ./scripts/codex-token-usage.sh <codex-home>    # directory containing sessions/
#   ./scripts/codex-token-usage.sh <rollout.jsonl> # explicit session file
#
# Exit codes:
#   0  summary printed (or soft no-op when no session / no usage)
#   1  bad usage or missing jq
set -euo pipefail

if ! command -v jq >/dev/null 2>&1; then
  echo "error: jq is required to parse Codex session output" >&2
  exit 1
fi

# shellcheck source=token-usage-summary.sh
source "$(dirname "$0")/token-usage-summary.sh"

resolve_rollout() {
  local target="${1:-}"

  if [[ -n "$target" && -f "$target" ]]; then
    printf '%s\n' "$target"
    return 0
  fi

  local home
  if [[ -n "$target" && -d "$target" ]]; then
    home="$target"
  elif [[ -n "${CODEX_HOME:-}" ]]; then
    home="$CODEX_HOME"
  else
    home="${HOME}/.codex"
  fi

  if [[ ! -d "$home/sessions" ]]; then
    echo "error: no sessions directory under: $home" >&2
    return 1
  fi

  # Newest rollout by mtime (portable: find + ls -t).
  local newest
  newest=$(find "$home/sessions" -type f \( -name 'rollout-*.jsonl' -o -name '*.jsonl' \) 2>/dev/null \
    | xargs ls -t 2>/dev/null \
    | head -n 1 || true)

  if [[ -z "$newest" || ! -f "$newest" ]]; then
    echo "error: no rollout JSONL found under: $home/sessions" >&2
    return 1
  fi

  printf '%s\n' "$newest"
}

TARGET="${1:-}"
if ! ROLLOUT=$(resolve_rollout "$TARGET"); then
  print_token_usage_summary "" 0 "${TARGET:-CODEX_HOME}"
  exit 0
fi

# Last turn.completed carries cumulative session usage.
USAGE=$(jq -c 'select(.type == "turn.completed" and .usage != null) | .usage' "$ROLLOUT" | tail -n 1 || true)
CALLS=$(jq -c 'select(.type == "turn.completed")' "$ROLLOUT" | wc -l | tr -d ' ')

if [[ -z "$USAGE" ]]; then
  # Fallback: some builds embed usage on token_count / event payloads.
  USAGE=$(jq -c '
    select(
      (.type == "token_count" and .info != null)
      or (.type == "event_msg" and .payload.type == "token_count")
      or (.usage != null and (.type | tostring | test("token|usage|completed")))
    )
    | (.usage // .info // .payload.info // .payload.usage // empty)
  ' "$ROLLOUT" | tail -n 1 || true)
fi

if [[ -z "$USAGE" ]]; then
  print_token_usage_summary "" "$CALLS" "$ROLLOUT"
  exit 0
fi

# Map Codex usage fields into the same Token type | Count table as Copilot.
# Keys mirror gen_ai.token.type style short labels (sorted for stable order).
TOTALS_JSONL=$(echo "$USAGE" | jq -c '
  [
    {key: "input",     value: (.input_tokens // .inputTokens // 0)},
    {key: "cached",    value: (.cached_input_tokens // .cachedInputTokens // 0)},
    {key: "output",    value: (.output_tokens // .outputTokens // 0)},
    {key: "reasoning", value: (.reasoning_output_tokens // .reasoningOutputTokens // 0)}
  ]
  | map(select(.value != 0))
  | sort_by(.key)
  | .[]
')

print_token_usage_summary "$TOTALS_JSONL" "$CALLS" "$ROLLOUT"
