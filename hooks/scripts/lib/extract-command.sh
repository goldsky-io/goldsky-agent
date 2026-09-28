#!/usr/bin/env bash

allow_command() {
  if [[ "$HOOK_HOST" == cursor ]]; then
    printf '{"permission":"allow"}\n'
  fi
  exit 0
}

block_command() {
  printf '%s\n' "$1" >&2
  if [[ "$HOOK_HOST" == cursor ]]; then
    jq -n --arg reason "$1" '{permission:"deny", user_message:$reason, agent_message:$reason}'
    exit 0
  fi
  exit 2
}

init_hook() {
  HOOK_HOST="${1:-claude}"
  INPUT=$(cat)
  command -v jq &>/dev/null || return 1
  COMMAND=$(printf '%s' "$INPUT" | jq -er '.tool_input.command // .command | select(type == "string")' 2>/dev/null) || return 1
  local cwd
  cwd=$(printf '%s' "$INPUT" | jq -er '.cwd // empty | select(type == "string")' 2>/dev/null) || cwd=""
  if [[ -n "$cwd" ]]; then
    cd -- "$cwd" 2>/dev/null || return 1
  fi
}

pipeline_file() {
  local rest="$COMMAND" token path="" count=0
  local word='^[[:blank:]]*("[^"$`\\]*"|\x27[^\x27]*\x27|[a-zA-Z0-9_./:=+-]+)($|[[:blank:]]+)'
  word=${word//\\x27/\'}
  local -a args=()
  # Parse only literal, simple commands; never evaluate shell input.
  while [[ "$rest" =~ $word ]]; do
    token=${BASH_REMATCH[1]}
    rest=${rest:${#BASH_REMATCH[0]}}
    case "$token" in
      \"*\"|\'*\') token=${token:1:${#token}-2} ;;
    esac
    args+=("$token")
  done
  [[ -z "$rest" && ${#args[@]} -ge 4 ]] || return 1
  [[ "${args[0]}" == goldsky && "${args[1]}" == turbo && "${args[2]}" == apply ]] || return 1
  for token in "${args[@]:3}"; do
    case "$token" in
      *.yaml|*.yml) path="$token"; count=$((count + 1)) ;;
    esac
  done
  [[ "$count" == 1 && "$path" != -* ]] || return 1
  printf '%s' "$path"
}
