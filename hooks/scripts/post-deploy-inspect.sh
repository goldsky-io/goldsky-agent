#!/usr/bin/env bash
# post-deploy-inspect — Suggests running inspect after a successful deploy
#
# PostToolUse hook for Bash commands. After a successful `goldsky turbo apply`,
# prints a suggestion to run `goldsky turbo inspect` to verify data flow.
#
# Input: JSON on stdin with { "tool_name": "Bash", "tool_input": { "command": "..." }, "tool_output": "..." }
# Exit 0: Always allow (PostToolUse hooks don't block)
# Stdout: Suggestion message shown to the user

set -euo pipefail

# Read stdin
INPUT=$(cat)

# Check if jq is available; fall through if not
if ! command -v jq &>/dev/null; then
  exit 0
fi

# Extract command and output
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // ""' 2>/dev/null)
OUTPUT=$(echo "$INPUT" | jq -r '.tool_output // ""' 2>/dev/null)

# Only fire after `goldsky turbo apply` commands
if ! echo "$COMMAND" | grep -qE 'goldsky\s+turbo\s+apply'; then
  exit 0
fi

# Check if the deploy was successful (look for success indicators in output)
if echo "$OUTPUT" | grep -qiE '(error|failed|failure|invalid)'; then
  # Deploy failed — don't suggest inspect
  exit 0
fi

# Check if the user already included inspect in the same command chain
if echo "$COMMAND" | grep -qE 'goldsky\s+turbo\s+inspect'; then
  exit 0
fi

# Extract pipeline name from the command or output
PIPELINE_NAME=""

# Try to get it from YAML file
YAML_FILE=""
if echo "$COMMAND" | grep -qE '\s+(-f|--file)\s+'; then
  YAML_FILE=$(echo "$COMMAND" | sed -nE 's/.*(-f|--file)\s+([^ ]+).*/\2/p')
else
  YAML_FILE=$(echo "$COMMAND" | grep -oE '[^ ]+\.(yaml|yml)' | tail -1)
fi

if [[ -n "$YAML_FILE" && -f "$YAML_FILE" ]]; then
  PIPELINE_NAME=$(grep -m1 -oE '^name:\s*(.+)' "$YAML_FILE" 2>/dev/null | sed 's/name:\s*//' | tr -d '"' || true)
fi

# Output the suggestion
echo ""
echo "Tip: Verify your pipeline is receiving data with:"
if [[ -n "$PIPELINE_NAME" ]]; then
  echo "  goldsky turbo inspect $PIPELINE_NAME"
else
  echo "  goldsky turbo inspect <pipeline-name>"
fi
echo ""
echo "This opens a live TUI showing records flowing through each stage."

exit 0
