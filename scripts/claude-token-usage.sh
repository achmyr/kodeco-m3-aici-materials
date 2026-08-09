#!/usr/bin/env bash
# Print token / cost usage from a Claude Code Action execution log.
#
# Used by .github/workflows/claude-code-review.yml after anthropics/claude-code-action.
# The action writes a JSON array of SDK messages to execution_file (typically
# $RUNNER_TEMP/claude-execution-output.json). The final message of type
# "result" carries total_cost_usd and modelUsage (per-model token counts).
#
# Console + GitHub Step Summary match scripts/ai-code-review.sh via
# scripts/token-usage-summary.sh.
#
# Usage:
#   ./scripts/claude-token-usage.sh <execution-file>
#
# Exit codes:
#   0  summary printed (or soft no-op when file missing / no result message)
#   1  bad usage or missing jq / unreadable file
set -euo pipefail

if [[ $# -lt 1 || -z "${1:-}" ]]; then
  echo "usage: $0 <execution-file>" >&2
  exit 1
fi

EXEC="$1"

if [[ ! -f "$EXEC" ]]; then
  echo "error: execution file not found: $EXEC" >&2
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "error: jq is required to parse Claude execution output" >&2
  exit 1
fi

# shellcheck source=token-usage-summary.sh
source "$(dirname "$0")/token-usage-summary.sh"

# Prefer the final result message (has total_cost_usd + modelUsage).
RESULT=$(jq -c '[.[] | select(.type == "result")] | last // empty' "$EXEC")
if [[ -z "$RESULT" ]]; then
  print_token_usage_summary "" 0 "$EXEC"
  exit 0
fi

CALLS=$(echo "$RESULT" | jq -r '.num_turns // 0')

# Aggregate modelUsage across models into the same token-type keys the Copilot
# OTel path uses (input / output / …). Fall back to top-level usage if needed.
TOTALS_JSONL=$(echo "$RESULT" | jq -c '
  def tokens:
    (.modelUsage // .model_usage // {}) as $m
    | if ($m | length) > 0 then
        [
          {key: "input",  value: ([$m[].inputTokens  // $m[].input_tokens  // 0] | add // 0)},
          {key: "output", value: ([$m[].outputTokens // $m[].output_tokens // 0] | add // 0)},
          {key: "cache_read",   value: ([$m[].cacheReadInputTokens   // $m[].cache_read_input_tokens   // 0] | add // 0)},
          {key: "cache_create", value: ([$m[].cacheCreationInputTokens // $m[].cache_creation_input_tokens // 0] | add // 0)}
        ]
      else
        (.usage // {}) as $u
        | [
          {key: "input",  value: ($u.input_tokens  // $u.inputTokens  // 0)},
          {key: "output", value: ($u.output_tokens // $u.outputTokens // 0)}
        ]
      end;
  tokens
  | map(select(.value != 0))
  | sort_by(.key)
  | .[]
')

print_token_usage_summary "$TOTALS_JSONL" "$CALLS" "$EXEC"
