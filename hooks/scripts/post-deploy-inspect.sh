#!/usr/bin/env bash
set -euo pipefail
# shellcheck source=hooks/scripts/lib/extract-command.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib/extract-command.sh"
init_hook "${1:-claude}" || exit 0
pipeline_file >/dev/null || exit 0
OUTPUT=$(printf '%s' "$INPUT" | jq -r '
  .tool_response // .output // .tool_output // empty |
  if type == "object" then [.stdout // "", .stderr // ""] | join("\n")
  elif type == "string" then . else empty end')
[[ -n "$OUTPUT" ]] || exit 0
if printf '%s' "$INPUT" | jq -e '(.tool_response.interrupted? == true) or ((.exit_code // .tool_response.exit_code? // 0) != 0)' >/dev/null; then
  exit 0
fi
if printf '%s\n' "$OUTPUT" | grep -qiE '(error|failed|failure|invalid)'; then
  exit 0
fi
MESSAGE="After a successful deploy, verify data flow with goldsky turbo inspect <pipeline-name>."
if [[ "$HOOK_HOST" == cursor ]]; then
  # Cursor's afterShellExecution has no documented context-injection response.
  printf '%s\n' "$MESSAGE" >&2
  printf '{}\n'
else
  jq -n --arg message "$MESSAGE" '{hookSpecificOutput:{hookEventName:"PostToolUse",additionalContext:$message}}'
fi
