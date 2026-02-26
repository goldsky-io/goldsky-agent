#!/usr/bin/env bash
# pre-deploy-validate — Validates pipeline YAML before goldsky turbo apply
#
# PreToolUse hook for Bash commands. Intercepts `goldsky turbo apply` and runs
# `goldsky turbo validate` first. Blocks the deploy if validation fails.
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
# Handles: goldsky turbo apply <file.yaml>
#          goldsky turbo apply -f <file.yaml>
#          goldsky turbo apply --file <file.yaml>
YAML_FILE=""

if echo "$COMMAND" | grep -qE '\s+(-f|--file)\s+'; then
  YAML_FILE=$(echo "$COMMAND" | sed -nE 's/.*(-f|--file)[[:space:]]+([^ ]+).*/\2/p')
else
  # Last argument that looks like a .yaml or .yml file
  YAML_FILE=$(echo "$COMMAND" | grep -oE '[^ ]+\.(yaml|yml)' | tail -1)
fi

# If we can't find a YAML file, allow the command (let the CLI handle it)
if [[ -z "$YAML_FILE" ]]; then
  exit 0
fi

# Check if the YAML file exists
if [[ ! -f "$YAML_FILE" ]]; then
  echo "Hook: pre-deploy-validate" >&2
  echo "YAML file not found: $YAML_FILE" >&2
  echo "Cannot validate pipeline before deploy." >&2
  exit 2
fi

# Check if goldsky CLI is available
if ! command -v goldsky &>/dev/null; then
  # CLI not installed — fall through and let the main command handle it
  exit 0
fi

# Run validation
VALIDATE_OUTPUT=$(goldsky turbo validate "$YAML_FILE" 2>&1) || {
  EXIT_CODE=$?
  echo "Hook: pre-deploy-validate" >&2
  echo "Pipeline validation failed. Fix these issues before deploying:" >&2
  echo "" >&2
  echo "$VALIDATE_OUTPUT" >&2
  exit 2
}

# Validation passed — allow the deploy
exit 0
