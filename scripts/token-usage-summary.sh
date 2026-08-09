#!/usr/bin/env bash
# Shared token-usage summary printer for AI review scripts.
#
# Emits the same console layout and GitHub Step Summary markdown used by
# scripts/ai-code-review.sh so Copilot / Claude / Codex jobs look identical.
#
# Source this file, then call:
#   print_token_usage_summary <totals_jsonl> <calls> [source_label]
#
# totals_jsonl: zero or more lines of compact JSON:
#   {"key":"input","value":1234}
#   {"key":"output","value":56}
# keys are token-type labels (sorted by the caller if order matters).
# calls: integer number of model calls / turns.
# source_label: optional text for the console "Token usage summary (from …)" line.
#
# Requires: jq (only if totals_jsonl is non-empty — caller may check first).

# Format an integer with thousands separators, portably (no numfmt/locale dependency).
format_number() {
  awk -v n="$1" 'BEGIN {
    n = int(n)
    s = sprintf("%d", n)
    out = ""
    len = length(s)
    for (i = 1; i <= len; i++) {
      out = out substr(s, i, 1)
      remaining = len - i
      if (remaining > 0 && remaining % 3 == 0) out = out ","
    }
    print out
  }'
}

# Print console + optional $GITHUB_STEP_SUMMARY in the canonical format.
print_token_usage_summary() {
  local totals_jsonl="${1:-}"
  local calls="${2:-0}"
  local source_label="${3:-}"

  if [[ -n "$source_label" ]]; then
    echo
    echo "Token usage summary (from $source_label):"
  fi

  if [[ -z "$totals_jsonl" ]]; then
    echo "  (no gen_ai.client.token.usage metrics recorded)"
    if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
      {
        echo "## AI Code Review – Token Usage"
        echo
        echo '_No `gen_ai.client.token.usage` metrics recorded._'
      } >> "$GITHUB_STEP_SUMMARY"
    fi
    return 0
  fi

  local total=0
  local token_type value
  while IFS= read -r entry; do
    [[ -z "$entry" ]] && continue
    token_type=$(echo "$entry" | jq -r '.key')
    value=$(echo "$entry" | jq -r '.value')
    total=$(awk -v a="$total" -v b="$value" 'BEGIN { print a + b }')
    printf '  %8s: %s tokens\n' "$token_type" "$(format_number "$value")"
  done <<< "$totals_jsonl"
  printf '  %8s: %s\n' "calls" "$calls"
  printf '  %8s: %s tokens\n' "total" "$(format_number "$total")"

  if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
    {
      echo "## AI Code Review – Token Usage"
      echo
      echo "| Token type | Count |"
      echo "| --- | ---: |"
      while IFS= read -r entry; do
        [[ -z "$entry" ]] && continue
        token_type=$(echo "$entry" | jq -r '.key')
        value=$(echo "$entry" | jq -r '.value')
        echo "| $token_type | $(format_number "$value") |"
      done <<< "$totals_jsonl"
      echo "| **total** | **$(format_number "$total")** |"
      echo
      echo "Calls: $calls"
    } >> "$GITHUB_STEP_SUMMARY"
  fi
}
