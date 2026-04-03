#!/usr/bin/env bash
# cli-validation — Validates Goldsky CLI commands before execution
#
# PreToolUse hook for Bash commands. Intercepts `goldsky` commands and blocks
# invalid subcommands (like `goldsky turbo stop`) with helpful suggestions.
#
# Input: JSON on stdin with { "tool_name": "Bash", "tool_input": { "command": "..." } }
# Exit 0: Allow the command to proceed
# Exit 2: Block the command (stderr is shown as the reason)

set -euo pipefail

# Read stdin
INPUT=$(cat)

# Extract the command from tool input
COMMAND=$(echo "$INPUT" | sed -n 's/.*"command"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')

# Only intercept `goldsky` commands
if ! echo "$COMMAND" | grep -qE '^goldsky[[:space:]]|[;&|]goldsky[[:space:]]'; then
  exit 0
fi

# Extract the goldsky subcommand (e.g., "turbo stop" from "goldsky turbo stop my-pipeline")
# Handle commands that might be chained with && or ;
GOLDSKY_CMD=$(echo "$COMMAND" | grep -oE 'goldsky[[:space:]]+[a-z]+[[:space:]]+[a-z]+' | head -1)

if [[ -z "$GOLDSKY_CMD" ]]; then
  # Single subcommand (like "goldsky login") - allow
  exit 0
fi

# Extract verb and subcommand (e.g., "turbo" and "stop")
VERB=$(echo "$GOLDSKY_CMD" | awk '{print $2}')
SUBCOMMAND=$(echo "$GOLDSKY_CMD" | awk '{print $3}')

# Validate turbo subcommands
if [[ "$VERB" == "turbo" ]]; then
  case "$SUBCOMMAND" in
    apply|validate|list|delete|pause|resume|restart|inspect|logs)
      # Valid turbo commands
      exit 0
      ;;
    stop)
      echo "Hook: cli-validation" >&2
      echo "" >&2
      echo "Invalid command: goldsky turbo stop" >&2
      echo "" >&2
      echo "'stop' is not a valid Goldsky CLI command." >&2
      echo "" >&2
      echo "Did you mean:" >&2
      echo "  - goldsky turbo pause <pipeline-name>   (temporarily stop, preserves state)" >&2
      echo "  - goldsky turbo delete <pipeline-name>  (permanently remove pipeline)" >&2
      exit 2
      ;;
    start)
      echo "Hook: cli-validation" >&2
      echo "" >&2
      echo "Invalid command: goldsky turbo start" >&2
      echo "" >&2
      echo "'start' is not a valid Goldsky CLI command." >&2
      echo "" >&2
      echo "Did you mean:" >&2
      echo "  - goldsky turbo apply <file.yaml>       (deploy a new pipeline)" >&2
      echo "  - goldsky turbo resume <pipeline-name>  (resume a paused pipeline)" >&2
      exit 2
      ;;
    run|execute)
      echo "Hook: cli-validation" >&2
      echo "" >&2
      echo "Invalid command: goldsky turbo $SUBCOMMAND" >&2
      echo "" >&2
      echo "'$SUBCOMMAND' is not a valid Goldsky CLI command." >&2
      echo "" >&2
      echo "Did you mean:" >&2
      echo "  - goldsky turbo apply <file.yaml>  (deploy a pipeline)" >&2
      exit 2
      ;;
    update)
      echo "Hook: cli-validation" >&2
      echo "" >&2
      echo "Invalid command: goldsky turbo update" >&2
      echo "" >&2
      echo "'update' is not a valid Goldsky CLI command." >&2
      echo "" >&2
      echo "Did you mean:" >&2
      echo "  - goldsky turbo apply <file.yaml>  (re-applying updates the pipeline in place)" >&2
      exit 2
      ;;
    status|info)
      echo "Hook: cli-validation" >&2
      echo "" >&2
      echo "Invalid command: goldsky turbo $SUBCOMMAND" >&2
      echo "" >&2
      echo "'$SUBCOMMAND' is not a valid Goldsky CLI command." >&2
      echo "" >&2
      echo "Did you mean:" >&2
      echo "  - goldsky turbo list  (list all pipelines with their status)" >&2
      exit 2
      ;;
    deploy|create)
      echo "Hook: cli-validation" >&2
      echo "" >&2
      echo "Invalid command: goldsky turbo $SUBCOMMAND" >&2
      echo "" >&2
      echo "'$SUBCOMMAND' is not a valid Goldsky CLI command." >&2
      echo "" >&2
      echo "Did you mean:" >&2
      echo "  - goldsky turbo apply <file.yaml>  (deploy/create a pipeline from YAML)" >&2
      exit 2
      ;;
    describe)
      echo "Hook: cli-validation" >&2
      echo "" >&2
      echo "Invalid command: goldsky turbo describe" >&2
      echo "" >&2
      echo "'describe' is not a valid Goldsky CLI command." >&2
      echo "" >&2
      echo "Did you mean:" >&2
      echo "  - goldsky turbo inspect <pipeline-name> -p  (view pipeline data)" >&2
      echo "  - goldsky turbo list                        (list pipelines)" >&2
      exit 2
      ;;
    *)
      # Unknown subcommand - let the CLI handle it (might be a new command)
      exit 0
      ;;
  esac
fi

# Validate secret subcommands
if [[ "$VERB" == "secret" ]]; then
  case "$SUBCOMMAND" in
    list|create|update|delete|reveal)
      exit 0
      ;;
    *)
      # Unknown - let CLI handle it
      exit 0
      ;;
  esac
fi

# Validate project subcommands
if [[ "$VERB" == "project" ]]; then
  case "$SUBCOMMAND" in
    list|create|users)
      exit 0
      ;;
    *)
      exit 0
      ;;
  esac
fi

# Validate dataset subcommands
if [[ "$VERB" == "dataset" ]]; then
  case "$SUBCOMMAND" in
    list)
      exit 0
      ;;
    *)
      exit 0
      ;;
  esac
fi

# All other goldsky commands - allow (let CLI handle unknown commands)
exit 0
