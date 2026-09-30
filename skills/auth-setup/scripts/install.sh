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
command -v curl >/dev/null || { echo 'curl and CA certificates are required.' >&2; exit 1; }
mkdir -p "$HOME/.local/bin" "$HOME/.goldsky/bin"
export PATH="$HOME/.local/bin:$HOME/.goldsky/bin:$PATH"

scratch=$(mktemp -d)
trap 'rm -rf "$scratch"' EXIT

download() {
  curl --fail --show-error --silent --location --connect-timeout 20 --max-time 180 \
    "$1" --output "$2" || return 1
  if [ ! -s "$2" ]; then
    echo "Empty download: $1" >&2
    return 1
  fi
}

if ! command -v goldsky >/dev/null || ! goldsky --version >/dev/null 2>&1; then
  download https://goldsky.com "$scratch/goldsky-install.sh"
  GOLDSKY_INSTALL_DIR="$HOME/.local/bin" bash "$scratch/goldsky-install.sh" -f
  hash -r
fi
goldsky --version

if [ "$component" = all ] || [ "$component" = compose ]; then
  compose_bin="$HOME/.goldsky/bin/compose"
  if [ ! -x "$compose_bin" ] || ! "$compose_bin" --version >/dev/null 2>&1; then
    download https://compose.goldsky.com/install "$scratch/compose-install.sh"
    sh "$scratch/compose-install.sh"
  fi
  goldsky compose --version
fi

if [ "$component" = all ] || [ "$component" = turbo ]; then
  turbo_bin="$HOME/.goldsky/bin/turbo"
  if [ ! -x "$turbo_bin" ] || ! "$turbo_bin" --version >/dev/null 2>&1; then
    if [ "$(uname -s)" = Darwin ] && [ "$(uname -m)" != arm64 ] && [ "$(sysctl -n hw.optional.arm64 2>/dev/null || true)" != 1 ]; then
      echo 'Turbo has no published Intel Mac binary. Full installation is incomplete. Use Apple Silicon or an x64 Ubuntu 24.04+ environment, or request only Compose.' >&2
      exit 1
    fi
    if [ "$(uname -s)" = Linux ]; then
      case "$(uname -m)" in
        x86_64|amd64) ;;
        *) echo 'Turbo has no published Linux ARM binary. Full installation is incomplete. Use an x64 Ubuntu 24.04+ environment, or request only Compose.' >&2; exit 1 ;;
      esac
      libc=$(getconf GNU_LIBC_VERSION 2>/dev/null || true)
      if ! printf '%s\n' "$libc" | awk '$1 == "glibc" { split($2, v, "."); if (v[1] > 2 || (v[1] == 2 && v[2] >= 39)) ok=1 } END { exit !ok }'; then
        echo 'The published Turbo Linux binary requires glibc 2.39+. Full installation is incomplete. Use x64 Ubuntu 24.04+ or request only Compose.' >&2
        exit 1
      fi
    fi
    download https://install-turbo.goldsky.com "$scratch/turbo-install.sh"
    INSTALL_DIR="$HOME/.goldsky/bin" bash "$scratch/turbo-install.sh"
  fi
  goldsky turbo --version
fi

printf 'Requested components verified. Authentication is a separate step.\n'
printf 'For each new shell: export PATH="$HOME/.local/bin:$HOME/.goldsky/bin:$PATH"\n'
