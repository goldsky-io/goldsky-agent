#!/usr/bin/env bash
# secret-check — Verifies secret_name references exist before deploying
#
# PreToolUse hook for Bash commands. Intercepts `goldsky turbo apply`, parses the
# pipeline YAML for `secret_name` references, and verifies each one exists via
# `goldsky secret list`. Blocks the deploy if any secrets are missing.
#
# Input: JSON on stdin with { "tool_name": "Bash", "tool_input": { "command": "..." } }
# Exit 0: Allow the command to proceed
# Exit 2: Block the command (stderr is shown as the reason)

set -euo pipefail

# Read stdin
INPUT=$(cat)

# Check if jq is available; fall through if not
if ! command -v jq &>/dev/null; then
  exit 0
fi

# Extract the command from tool input
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // ""' 2>/dev/null)

# Only intercept `goldsky turbo apply` commands
if ! echo "$COMMAND" | grep -qE 'goldsky\s+turbo\s+apply'; then
  exit 0
fi

# Extract the YAML file path from the command
YAML_FILE=""

if echo "$COMMAND" | grep -qE '\s+(-f|--file)\s+'; then
  YAML_FILE=$(echo "$COMMAND" | sed -nE 's/.*(-f|--file)\s+([^ ]+).*/\2/p')
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
SECRET_NAMES=$(grep -oE 'secret_name:\s*"?([a-zA-Z0-9_-]+)"?' "$YAML_FILE" 2>/dev/null \
  | sed -E 's/secret_name:\s*"?([a-zA-Z0-9_-]+)"?/\1/' \
  | sort -u)

# If no secrets referenced, allow the command
if [[ -z "$SECRET_NAMES" ]]; then
  exit 0
fi

# Get the list of existing secrets
EXISTING_SECRETS=$(goldsky secret list 2>/dev/null | grep -oE '^[a-zA-Z0-9_-]+' || true)

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
  echo "Or use the /goldsky-secrets skill for help." >&2
  exit 2
fi

# All secrets exist — allow the deploy
exit 0
