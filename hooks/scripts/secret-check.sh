#!/usr/bin/env bash
# secret-check — Verifies secret_name references exist before deploying
#
# PreToolUse hook for Bash commands. Intercepts `goldsky turbo apply`, parses the
# pipeline YAML for `secret_name` references, and verifies each one exists via
# `goldsky secret list`. Blocks the deploy if any secrets are missing.
#
# Input: JSON on stdin. Claude Code sends { "tool_input": { "command": "..." } };
#        Cursor sends { "command": "..." }. Both are handled by extract_command.
# Exit 0: Allow the command to proceed
# Exit 2: Block the command (stderr is shown as the reason)

set -euo pipefail

# Read stdin
INPUT=$(cat)

# Extract the command from tool input
# shellcheck source=hooks/scripts/lib/extract-command.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib/extract-command.sh"
COMMAND=$(extract_command "$INPUT")

# No command in the payload (or no jq available) — nothing to inspect.
if [[ -z "$COMMAND" ]]; then
  exit 0
fi

# Only intercept `goldsky turbo apply` commands
if ! echo "$COMMAND" | grep -qE 'goldsky[[:space:]]+turbo[[:space:]]+apply'; then
  exit 0
fi

# Extract the YAML file path from the command
YAML_FILE=""

if echo "$COMMAND" | grep -qE '[[:space:]]+(-f|--file)[[:space:]]+'; then
  YAML_FILE=$(echo "$COMMAND" | sed -nE 's/.*(-f|--file)[[:space:]]+([^ ]+).*/\2/p')
else
  YAML_FILE=$(echo "$COMMAND" | grep -oE '[^ ]+\.(yaml|yml)' | tail -1)
fi

# If we can't find a YAML file, allow the command
if [[ -z "$YAML_FILE" ]]; then
  exit 0
fi

# If the YAML file doesn't exist, allow (pre-deploy-validate will catch it)
if [[ ! -f "$YAML_FILE" ]]; then
  exit 0
fi

# Check if goldsky CLI is available
if ! command -v goldsky &>/dev/null; then
  exit 0
fi

# Extract secret_name values from the YAML file
# Looks for patterns like: secret_name: my-secret or secret_name: "my-secret"
SECRET_NAMES=$(grep -oE 'secret_name:[[:space:]]*"?([a-zA-Z0-9._-]+)"?' "$YAML_FILE" 2>/dev/null \
  | sed -E 's/secret_name:[[:space:]]*"?([a-zA-Z0-9._-]+)"?/\1/' \
  | sort -u)

# If no secrets referenced, allow the command
if [[ -z "$SECRET_NAMES" ]]; then
  exit 0
fi

# Get the list of existing secrets.
#
# The CLI has no JSON output for this (checked against 13.x), so we parse the
# table. Two rules matter here:
#   1. Be tolerant of formatting — disable colour, strip any ANSI that leaks
#      through, and accept any vertical-bar separator rather than hard-coding
#      the U+2502 box-drawing character, which changes between CLI versions.
#   2. FAIL OPEN. If the command errors (not logged in, network down) or the
#      output doesn't parse, we must not block the deploy — an unparseable
#      list previously looked identical to "you have zero secrets", which
#      blocked every apply with a bogus "missing secret" message.
SECRET_LIST_RAW=$(goldsky secret list --no-color 2>/dev/null) || SECRET_LIST_RAW=""

if [[ -z "$SECRET_LIST_RAW" ]]; then
  # Could not reach the CLI or got nothing back — allow and let the CLI decide.
  exit 0
fi

#
# Parse byte-safely: strip ANSI, drop every leading character that cannot start
# a secret name, then truncate at the first character that cannot appear in one.
# That handles any separator — U+2502, ASCII '|', or plain whitespace columns —
# without matching multibyte characters, which a sed bracket expression cannot
# do reliably. Border rows reduce to empty and are filtered out.
EXISTING_SECRETS=$(printf '%s\n' "$SECRET_LIST_RAW" \
  | sed -E $'s/\033\\[[0-9;]*[a-zA-Z]//g' \
  | sed -E 's/^[^A-Za-z0-9]*//' \
  | sed -E 's/[^A-Za-z0-9._-].*$//' \
  | grep -E '^[A-Za-z0-9._-]+$' \
  | grep -vxiE 'name|type|secret' \
  || true)

if [[ -z "$EXISTING_SECRETS" ]]; then
  # Table present but nothing parsed out of it: the format changed. Warn on
  # stderr so it gets noticed and fixed, but do not block the deploy.
  echo "Hook: secret-check — could not parse 'goldsky secret list' output; skipping the check." >&2
  exit 0
fi

# Check each referenced secret
MISSING_SECRETS=()
while IFS= read -r secret; do
  [[ -z "$secret" ]] && continue
  if ! echo "$EXISTING_SECRETS" | grep -qx "$secret"; then
    MISSING_SECRETS+=("$secret")
  fi
done <<< "$SECRET_NAMES"

# If any secrets are missing, block the deploy
if [[ ${#MISSING_SECRETS[@]} -gt 0 ]]; then
  echo "Hook: secret-check" >&2
  echo "Pipeline references secrets that don't exist in your project:" >&2
  echo "" >&2
  for secret in "${MISSING_SECRETS[@]}"; do
    echo "  - $secret" >&2
  done
  echo "" >&2
  echo "Create them first with:" >&2
  for secret in "${MISSING_SECRETS[@]}"; do
    echo "  goldsky secret create $secret --value <connection-string>" >&2
  done
  echo "" >&2
  echo "Or use the /secrets skill for help." >&2
  exit 2
fi

# All secrets exist — allow the deploy
exit 0
