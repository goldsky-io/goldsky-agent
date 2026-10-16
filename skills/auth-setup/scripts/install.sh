#!/usr/bin/env bash
set -euo pipefail

component=${1:-all}
case "$component" in
  all|cli|compose|turbo) ;;
  *) echo 'Usage: bash install.sh [all|cli|compose|turbo]' >&2; exit 2 ;;
esac
if [ "$#" -gt 1 ]; then
  echo 'Usage: bash install.sh [all|cli|compose|turbo]' >&2
  exit 2
fi

case "$(uname -s)" in
  Darwin|Linux) ;;
  *) echo 'Run this installer inside WSL on Windows; see auth-setup.' >&2; exit 1 ;;
esac
: "${HOME:?A writable home directory is required}"
command -v npm >/dev/null 2>&1 || { echo 'npm is required.' >&2; exit 1; }

mkdir -p "$HOME/.local/bin" "$HOME/.goldsky/bin"
export PATH="$HOME/.local/bin:$HOME/.goldsky/bin:$PATH"
export npm_config_yes=true

# Minimum version: 13.16.0 added `turbo install`, 13.17.0 added `feeds key reveal`.
npm install --global --prefix "$HOME/.local" "@goldskycom/cli@^13.17.0"
hash -r

cli_version=$(goldsky --version 2>&1) || { echo 'goldsky --version failed.' >&2; exit 1; }
printf '%s\n' "$cli_version"
# A first run prints a telemetry notice before the version line.
cli_ok=
while IFS= read -r line; do
  case "$line" in
    13.1[7-9].*|13.[2-9][0-9].*|13.[1-9][0-9][0-9]*.*) cli_ok=1; break ;;
  esac
done <<< "$cli_version"
[ -n "$cli_ok" ] || { echo 'Expected Goldsky CLI 13.17.0 or a newer 13.x.' >&2; exit 1; }

if [ "$component" = all ] || [ "$component" = compose ]; then
  goldsky compose install
  goldsky compose --version
fi

if [ "$component" = all ] || [ "$component" = turbo ]; then
  turbo_status=0
  turbo_log=$(goldsky turbo install 2>&1) || turbo_status=$?
  case "$turbo_log" in
    *'not a Goldsky Turbo command'*|*'unrecognized subcommand'*|*'not available'*)
      echo 'goldsky turbo install is not available in this CLI.' >&2
      exit 1
      ;;
  esac
  if [ "$turbo_status" -ne 0 ]; then
    echo 'goldsky turbo install failed.' >&2
    exit 1
  fi
  goldsky turbo --version
fi

printf 'Requested components verified. Authentication is a separate step.\n'
printf 'For each new shell: export PATH="$HOME/.local/bin:$HOME/.goldsky/bin:$PATH"\n'
