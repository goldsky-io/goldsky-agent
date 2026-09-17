#!/usr/bin/env bash
# Shared helper: pull the shell command out of a hook payload.
#
# Sourced by the hook scripts. Takes the JSON payload as $1 and echoes the
# command string, or nothing when the payload carries no command.
#
# Host payload shapes differ, so try each known location:
#   Claude Code  PreToolUse / PostToolUse      -> .tool_input.command
#   Cursor       before/afterShellExecution    -> .command
#
# Uses jq rather than a sed regex: any command containing an escaped quote
# (e.g. goldsky secret create --value "{\"host\":\"db\"}") silently truncates
# under a regex, which made these hooks skip the very commands they guard.
extract_command() {
  local input="$1"
  if command -v jq &>/dev/null; then
    printf '%s' "$input" | jq -r '.tool_input.command // .command // empty' 2>/dev/null
  else
    # jq missing: emit nothing so the caller allows the command through,
    # rather than guessing with a regex and blocking on a bad parse.
    printf ''
  fi
}
