#!/usr/bin/env bash
# Print token usage from a Codex CLI session rollout (JSONL).
#
# Used by .github/workflows/codex-review.yml after openai/codex-action.
# Codex does not expose token counts as Action outputs. Instead it writes
# session rollouts under $CODEX_HOME/sessions/YYYY/MM/DD/rollout-*.jsonl.
#
# Session rollouts typically look like:
#   {"type":"event_msg","payload":{"type":"token_count","info":{
#     "total_token_usage":{"input_tokens":…,"cached_input_tokens":…,
#       "output_tokens":…,"reasoning_output_tokens":…,"total_tokens":…},
#     "last_token_usage":{…}}}}
# `total_token_usage` is cumulative for the session — take the *last* event.
#
# `codex exec --json` streams a flatter shape:
#   {"type":"turn.completed","usage":{"input_tokens":…,…}}
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

# Flatten any known Codex usage shape into {input_tokens, cached_input_tokens, …}.
# Returns empty if the object is not a usable TokenUsage payload.
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
  print_token_usage_summary "" 0 "${TARGET:-CODEX_HOME}"
  exit 0
fi

# Last matching event carries the best cumulative session totals.
USAGE=$(jq -c "$normalize_usage_jq" "$ROLLOUT" 2>/dev/null | tail -n 1 || true)

# Prefer completed turns; fall back to token_count events (one per model call).
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

# Map Codex usage fields into the same Token type | Count table as Copilot.
# Keys mirror gen_ai.token.type style short labels (sorted for stable order).
# Emit breakdown rows plus an optional explicit total (Codex total_tokens is
# authoritative; input already includes cached so summing would double-count).
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
