#!/usr/bin/env bash
set -euo pipefail
# shellcheck source=hooks/scripts/lib/extract-command.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib/extract-command.sh"
init_hook "${1:-claude}" || allow_command
YAML_FILE=$(pipeline_file) || allow_command
[[ -f "$YAML_FILE" ]] || block_command "YAML file not found: $YAML_FILE. Cannot validate pipeline before deploy."
command -v goldsky &>/dev/null || allow_command
if ! goldsky turbo validate "$YAML_FILE" >/dev/null 2>&1; then
  block_command "Pipeline validation failed. Run goldsky turbo validate on the pipeline file and fix the errors before deploying."
fi
allow_command
