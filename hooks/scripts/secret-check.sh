#!/usr/bin/env bash
set -euo pipefail
# shellcheck source=hooks/scripts/lib/extract-command.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib/extract-command.sh"
init_hook "${1:-claude}" || allow_command
YAML_FILE=$(pipeline_file) || allow_command
[[ -f "$YAML_FILE" ]] || allow_command
command -v goldsky &>/dev/null || allow_command

SECRET_NAMES=$(sed -nE "s/^[[:space:]]*secret_name:[[:space:]]*[\"']?([A-Za-z0-9._-]+)[\"']?[[:space:]]*(#.*)?$/\\1/p" "$YAML_FILE" | sort -u)
[[ -n "$SECRET_NAMES" ]] || allow_command
SECRET_LIST_RAW=$(goldsky secret list --no-color 2>/dev/null) || allow_command
SECRET_LIST_RAW=$(printf '%s\n' "$SECRET_LIST_RAW" | sed -E $'s/\033\\[[0-9;]*[a-zA-Z]//g' | sed 's/│/|/g')

if printf '%s\n' "$SECRET_LIST_RAW" | grep -q '^No secrets found\.'; then
  EXISTING_SECRETS=""
elif printf '%s\n' "$SECRET_LIST_RAW" | grep -qE 'Name[[:space:]]*[|][[:space:]]*Type'; then
  EXISTING_SECRETS=$(printf '%s\n' "$SECRET_LIST_RAW" \
    | sed -E 's/^[^A-Za-z0-9]*//' \
    | sed -nE 's/^([A-Za-z0-9._-]+)[[:space:]]*[|].*/\1/p' \
    | grep -vx 'Name' || true)
  [[ -n "$EXISTING_SECRETS" ]] || allow_command
else
  printf '%s\n' "Hook: secret-check — unrecognized secret list; skipping the check." >&2
  allow_command
fi

MISSING_SECRETS=()
while IFS= read -r secret; do
  if ! printf '%s\n' "$EXISTING_SECRETS" | grep -Fxq -- "$secret"; then
    MISSING_SECRETS+=("$secret")
  fi
done <<< "$SECRET_NAMES"
if [[ ${#MISSING_SECRETS[@]} -gt 0 ]]; then
  block_command "Pipeline references missing secrets: ${MISSING_SECRETS[*]}. Create them with goldsky secret create or use the secrets skill."
fi
allow_command
