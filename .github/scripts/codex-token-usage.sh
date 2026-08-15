#!/usr/bin/env bash
# Print token usage from a Codex CLI session rollout (CI only).
#
# Used by .github/workflows/codex-review.yml after openai/codex-action.
# Codex writes session rollouts under $CODEX_HOME/sessions/YYYY/MM/DD/rollout-*.jsonl.
#
# Usage:
#   .github/scripts/codex-token-usage.sh <codex-home>
#   .github/scripts/codex-token-usage.sh <rollout.jsonl>
set -euo pipefail

if ! command -v jq >/dev/null 2>&1; then
  echo "error: jq is required to parse Codex session output" >&2
  exit 1
fi

# shellcheck source=token-usage-summary.sh
source "$(dirname "$0")/token-usage-summary.sh"

resolve_rollout() {
  local target="${1:-}"

  if [[ -z "$target" ]]; then
    echo "error: codex-home or rollout file required" >&2
    return 1
  fi

  if [[ -f "$target" ]]; then
    printf '%s\n' "$target"
    return 0
  fi

  if [[ ! -d "$target" ]]; then
    echo "error: not a file or directory: $target" >&2
    return 1
  fi

  if [[ ! -d "$target/sessions" ]]; then
    echo "error: no sessions directory under: $target" >&2
    return 1
  fi

  local newest
  newest=$(find "$target/sessions" -type f \( -name 'rollout-*.jsonl' -o -name '*.jsonl' \) 2>/dev/null \
    | xargs ls -t 2>/dev/null \
    | head -n 1 || true)

  if [[ -z "$newest" || ! -f "$newest" ]]; then
    echo "error: no rollout JSONL found under: $target/sessions" >&2
    return 1
  fi

  printf '%s\n' "$newest"
}

normalize_usage_jq='
  def as_usage:
    if type != "object" then empty
    elif (.input_tokens // .inputTokens // .output_tokens // .outputTokens // .total_tokens // .totalTokens) != null then
      {
        input_tokens: (.input_tokens // .inputTokens // 0),
        cached_input_tokens: (.cached_input_tokens // .cachedInputTokens // 0),
        output_tokens: (.output_tokens // .outputTokens // 0),
        reasoning_output_tokens: (.reasoning_output_tokens // .reasoningOutputTokens // 0),
        total_tokens: (.total_tokens // .totalTokens // 0)
      }
    elif .total_token_usage != null then (.total_token_usage | as_usage)
    elif .last_token_usage != null then (.last_token_usage | as_usage)
    else empty
    end;

  if .type == "event_msg" and .payload.type == "token_count" then
    (.payload.info | as_usage)
  elif .type == "token_count" then
    ((.info // .) | as_usage)
  elif .type == "turn.completed" and .usage != null then
    (.usage | as_usage)
  elif .usage != null then
    (.usage | as_usage)
  else empty
  end
'

TARGET="${1:-}"
if ! ROLLOUT=$(resolve_rollout "$TARGET"); then
  print_token_usage_summary "" 0 "${TARGET:-codex-home}"
  exit 0
fi

USAGE=$(jq -c "$normalize_usage_jq" "$ROLLOUT" 2>/dev/null | tail -n 1 || true)

CALLS=$(jq -c '
  select(
    .type == "turn.completed"
    or .type == "task_complete"
    or .type == "turn_complete"
    or (.type == "event_msg" and (.payload.type == "task_complete" or .payload.type == "turn_complete"))
  )
' "$ROLLOUT" 2>/dev/null | wc -l | tr -d ' ' || true)
if [[ "${CALLS:-0}" -eq 0 ]]; then
  CALLS=$(jq -c '
    select(
      (.type == "event_msg" and .payload.type == "token_count")
      or .type == "token_count"
    )
  ' "$ROLLOUT" 2>/dev/null | wc -l | tr -d ' ' || true)
fi
CALLS="${CALLS:-0}"

if [[ -z "$USAGE" ]]; then
  print_token_usage_summary "" "$CALLS" "$ROLLOUT"
  exit 0
fi

TOTALS_JSONL=$(echo "$USAGE" | jq -c '
  . as $u
  | (
      [
        {key: "input",     value: ($u.input_tokens // 0)},
        {key: "cached",    value: ($u.cached_input_tokens // 0)},
        {key: "output",    value: ($u.output_tokens // 0)},
        {key: "reasoning", value: ($u.reasoning_output_tokens // 0)}
      ]
      | map(select(.value != 0))
      | sort_by(.key)
      | .[]
    ),
    (if ($u.total_tokens // 0) != 0 then {key: "total", value: $u.total_tokens} else empty end)
')

print_token_usage_summary "$TOTALS_JSONL" "$CALLS" "$ROLLOUT"
