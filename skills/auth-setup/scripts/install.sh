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

npm install --global --prefix "$HOME/.local" @goldskycom/cli@13.15.1
hash -r

cli_version=$(goldsky --version 2>&1) || { echo 'goldsky --version failed.' >&2; exit 1; }
printf '%s\n' "$cli_version"
case "$cli_version" in
  *13.15.1*) ;;
  *) echo 'Expected Goldsky CLI 13.15.1.' >&2; exit 1 ;;
esac

if [ "$component" = all ] || [ "$component" = compose ]; then
  goldsky compose install
  goldsky compose --version
fi

if [ "$component" = all ] || [ "$component" = turbo ]; then
  turbo_status=0
  turbo_log=$(goldsky turbo install 2>&1) || turbo_status=$?
  printf '%s\n' "$turbo_log"
  case "$turbo_log" in
    *'not a Goldsky Turbo command'*|*'unrecognized subcommand'*)
      echo 'goldsky turbo install is not available in this CLI.' >&2
      exit 1
      ;;
  esac
  [ "$turbo_status" -eq 0 ]
  goldsky turbo --version
fi

printf 'Requested components verified. Authentication is a separate step.\n'
printf 'For each new shell: export PATH="$HOME/.local/bin:$HOME/.goldsky/bin:$PATH"\n'
