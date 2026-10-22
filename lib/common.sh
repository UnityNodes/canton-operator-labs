#!/usr/bin/env bash
set -euo pipefail

LABS_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LABS_STATE="$LABS_ROOT/.state"
LABS_CACHE="$LABS_ROOT/.localnet"
LABS_PROJECT="canton-labs"
SPLICE_REPO="${SPLICE_REPO:-https://github.com/canton-network/splice.git}"
LOCALNET_CONTAINERS="canton splice postgres nginx swagger-ui"

say()  { printf '\033[1m==>\033[0m %s\n' "$*" >&2; }
ok()   { printf '  \033[32mPASS\033[0m %s\n' "$*"; }
bad()  { printf '  \033[31mFAIL\033[0m %s\n' "$*"; }
die()  { printf '\033[31merror:\033[0m %s\n' "$*" >&2; exit 1; }

valid_version() { [[ "$1" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; }

version_at_least() {
  local have="$1" want="$2" i x y
  local -a a b
  IFS=. read -r -a a <<< "$have"
  IFS=. read -r -a b <<< "$want"
  for i in 0 1 2; do
    x="${a[$i]:-0}"; y="${b[$i]:-0}"
    x="${x%%[!0-9]*}"; y="${y%%[!0-9]*}"
    [ "${x:-0}" -gt "${y:-0}" ] && return 0
    [ "${x:-0}" -lt "${y:-0}" ] && return 1
  done
  return 0
}

need() {
  local missing=()
  for tool in "$@"; do command -v "$tool" >/dev/null 2>&1 || missing+=("$tool"); done
  [ ${#missing[@]} -eq 0 ] || die "missing tools: ${missing[*]}"
  docker compose version >/dev/null 2>&1 || die "docker compose v2 is required"
}

preflight() {
  [ "${LABS_SKIP_PREFLIGHT:-0}" = "1" ] && return 0
  local endpoint="${DOCKER_HOST:-}"
  [ -n "$endpoint" ] || endpoint="$(docker context inspect --format '{{(index .Endpoints "docker").Host}}' 2>/dev/null || true)"
  case "$endpoint" in
    tcp://*|ssh://*)
      [ "${LABS_ALLOW_REMOTE_DOCKER:-0}" = "1" ] \
        || die "Docker points at a remote machine ($endpoint). The labs would start LocalNet and delete volumes there. Use a local Docker, or set LABS_ALLOW_REMOTE_DOCKER=1 if you mean it." ;;
  esac
  docker info >/dev/null 2>&1 || die "Docker is not running, or this user may not use it. Start Docker and try again."
  local compose_have; compose_have="$(docker compose version --short 2>/dev/null | sed 's/^v//')"
  version_at_least "${compose_have:-0}" 2.24.0 || die "Docker Compose 2.24 or newer is required (found ${compose_have:-none})"
  local mem; mem="$(docker info --format '{{.MemTotal}}' 2>/dev/null || echo 0)"
  [ "${mem:-0}" -ge 12884901888 ] 2>/dev/null \
    || die "Docker has $(( ${mem:-0} / 1073741824 )) GB of memory and the labs need 12 GB or more (16 GB is recommended). Raise it in Docker Desktop, or set LABS_SKIP_PREFLIGHT=1 to try anyway."
  local name owner
  for name in $LOCALNET_CONTAINERS; do
    docker container inspect "$name" >/dev/null 2>&1 || continue
    owner="$(docker container inspect --format '{{index .Config.Labels "com.docker.compose.project"}}' "$name" 2>/dev/null || true)"
    [ "$owner" = "$LABS_PROJECT" ] \
      || die "a container named '$name' already exists and is not part of these labs. LocalNet uses fixed container names, so run the labs on a machine without it."
  done
}

state_set() { mkdir -p "$LABS_STATE"; printf '%s' "$2" > "$LABS_STATE/$1"; }
state_get() { cat "$LABS_STATE/$1" 2>/dev/null || true; }
