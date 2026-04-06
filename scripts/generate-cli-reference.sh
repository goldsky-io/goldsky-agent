#!/usr/bin/env bash
# generate-cli-reference — Generates a CLI reference file from the installed goldsky CLI.
#
# Usage: ./scripts/generate-cli-reference.sh
#
# Output: data/goldsky-cli-reference.md
#
# Run this whenever the Goldsky CLI is updated to keep the reference current.

set -euo pipefail

OUT="$(dirname "$0")/../skills/cli-reference/SKILL.md"
mkdir -p "$(dirname "$OUT")"

# Strip the update notification banner from help output
strip_banner() {
  sed '/^┌/,/^└/d'
}

# Extract subcommand names from a Commands: section in --help output
parse_subcommands() {
  awk '/^Commands:/{found=1; next} found && /^  [a-z]/{print $1} found && /^Options:/{exit}'
}

CLI_VERSION=$(goldsky turbo --version 2>/dev/null | head -1 || echo "unknown")

{
  echo "---"
  echo "name: cli-reference"
  echo "description: \"Goldsky CLI command and flag reference — all valid subcommands, arguments, and options for goldsky turbo, secret, project, and dataset. Consult before suggesting any goldsky command.\""
  echo "---"
  echo ""
  echo "# Goldsky CLI Reference"
  echo ""
  echo "> Generated from installed CLI ($CLI_VERSION). Re-run \`scripts/generate-cli-reference.sh\` to update."
  echo ""

  # ── goldsky turbo ──────────────────────────────────────────────────────────
  echo "## goldsky turbo"
  echo ""
  TURBO_HELP=$(goldsky turbo --help 2>&1 | strip_banner)
  TURBO_DESC=$(echo "$TURBO_HELP" | sed -n '2p')
  echo "$TURBO_DESC"
  echo ""

  TURBO_CMDS=$(echo "$TURBO_HELP" | parse_subcommands | grep -v '^help$' || true)

  echo "### Subcommands"
  echo ""
  while IFS= read -r cmd; do
    CMD_HELP=$(goldsky turbo "$cmd" --help 2>&1 | strip_banner)
    CMD_DESC=$(echo "$CMD_HELP" | head -1)
    echo "#### \`goldsky turbo $cmd\`"
    echo ""
    echo "$CMD_DESC"
    echo ""

    # Arguments
    ARGS=$(echo "$CMD_HELP" | awk '/^Arguments:/{found=1; next} found && /^  /{print} found && /^$/{exit} found && /^[A-Z]/{exit}')
    if [[ -n "$ARGS" ]]; then
      echo "**Arguments:**"
      echo ""
      echo "$ARGS" | sed 's/^/  /'
      echo ""
    fi

    # Options (skip -h/--help)
    OPTS=$(echo "$CMD_HELP" | awk '/^Options:/{found=1; next} found && /^ *-/{print} found && /^$/{exit} found && /^[A-Z]/{exit}' | grep -v -- '-h,\s*--help\|--help$' || true)
    if [[ -n "$OPTS" ]]; then
      echo "**Options:**"
      echo ""
      echo "$OPTS" | sed 's/^/  /'
      echo ""
    fi

    # Sub-subcommands (e.g. turbo state)
    SUBCMDS=$(echo "$CMD_HELP" | parse_subcommands | grep -v '^help$' || true)
    if [[ -n "$SUBCMDS" ]]; then
      echo "**Subcommands:** $(echo "$SUBCMDS" | tr '\n' ' ')"
      echo ""
    fi
  done <<< "$TURBO_CMDS"

  # parse_yargs_subcommands: for TypeScript CLI commands like "goldsky secret create ..."
  # extracts the 3rd word (the subcommand) from each Commands: line
  parse_yargs_subcommands() {
    awk '/^Commands:/{found=1; next} found && /^  goldsky [a-z]/{print $3} found && /^Options:/{exit}'
  }

  # ── goldsky secret ─────────────────────────────────────────────────────────
  echo "## goldsky secret"
  echo ""
  SECRET_HELP=$(goldsky secret --help 2>&1 | strip_banner)
  SECRET_CMDS=$(echo "$SECRET_HELP" | parse_yargs_subcommands || true)
  echo "Subcommands: $(echo "$SECRET_CMDS" | tr '\n' ' ')"
  echo ""

  # ── goldsky project ────────────────────────────────────────────────────────
  echo "## goldsky project"
  echo ""
  PROJECT_HELP=$(goldsky project --help 2>&1 | strip_banner)
  PROJECT_CMDS=$(echo "$PROJECT_HELP" | parse_yargs_subcommands || true)
  echo "Subcommands: $(echo "$PROJECT_CMDS" | tr '\n' ' ')"
  echo ""

  # ── goldsky dataset ────────────────────────────────────────────────────────
  echo "## goldsky dataset"
  echo ""
  DATASET_HELP=$(goldsky dataset --help 2>&1 | strip_banner)
  DATASET_CMDS=$(echo "$DATASET_HELP" | parse_yargs_subcommands || true)
  echo "Subcommands: $(echo "$DATASET_CMDS" | tr '\n' ' ')"
  echo ""

} > "$OUT"

echo "Generated: $OUT"
