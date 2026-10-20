#!/usr/bin/env bash
set -euo pipefail

LABS_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LABS_STATE="${LABS_STATE:-$LABS_ROOT/.state}"
LABS_CACHE="${LABS_CACHE:-$LABS_ROOT/.localnet}"
LABS_PROJECT="${LABS_PROJECT:-canton-labs}"
SPLICE_REPO="${SPLICE_REPO:-https://github.com/hyperledger-labs/splice.git}"

say()  { printf '\033[1m==>\033[0m %s\n' "$*" >&2; }
ok()   { printf '  \033[32mPASS\033[0m %s\n' "$*"; }
bad()  { printf '  \033[31mFAIL\033[0m %s\n' "$*"; }
die()  { printf '\033[31merror:\033[0m %s\n' "$*" >&2; exit 1; }

need() {
  local missing=()
  for tool in "$@"; do command -v "$tool" >/dev/null 2>&1 || missing+=("$tool"); done
  [ ${#missing[@]} -eq 0 ] || die "missing tools: ${missing[*]}"
  docker compose version >/dev/null 2>&1 || die "docker compose v2 is required"
}

state_set() { mkdir -p "$LABS_STATE"; printf '%s' "$2" > "$LABS_STATE/$1"; }
state_get() { cat "$LABS_STATE/$1" 2>/dev/null || true; }
