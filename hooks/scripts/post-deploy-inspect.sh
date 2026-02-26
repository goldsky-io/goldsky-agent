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

# Extract command and output
COMMAND=$(echo "$INPUT" | sed -n 's/.*"command"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
OUTPUT=$(echo "$INPUT" | sed -n 's/.*"tool_output"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')

# Only fire after `goldsky turbo apply` commands
if ! echo "$COMMAND" | grep -qE 'goldsky[[:space:]]+turbo[[:space:]]+apply'; then
  exit 0
fi

# Check if the deploy was successful (look for success indicators in output)
if echo "$OUTPUT" | grep -qiE '(error|failed|failure|invalid)'; then
  # Deploy failed — don't suggest inspect
  exit 0
fi

# Check if the user already included inspect in the same command chain
if echo "$COMMAND" | grep -qE 'goldsky[[:space:]]+turbo[[:space:]]+inspect'; then
  exit 0
fi

# Extract pipeline name from the command or output
PIPELINE_NAME=""

# Try to get it from YAML file
YAML_FILE=""
if echo "$COMMAND" | grep -qE '[[:space:]]+(-f|--file)[[:space:]]+'; then
  YAML_FILE=$(echo "$COMMAND" | sed -nE 's/.*(-f|--file)[[:space:]]+([^ ]+).*/\2/p')
else
  YAML_FILE=$(echo "$COMMAND" | grep -oE '[^ ]+\.(yaml|yml)' | tail -1)
fi

if [[ -n "$YAML_FILE" && -f "$YAML_FILE" ]]; then
  PIPELINE_NAME=$(grep -m1 -oE '^name:[[:space:]]*(.+)' "$YAML_FILE" 2>/dev/null | sed -E 's/name:[[:space:]]*//' | tr -d '"' || true)
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
