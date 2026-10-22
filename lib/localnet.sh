#!/usr/bin/env bash

pinned_commit() {
  case "$1" in
    0.8.4) printf '%s' fa6b029f2563423f3f612302cfdc84986366479d ;;
    0.9.2) printf '%s' 60882e4de07a1f146a7d615e44c52a17fe40419f ;;
    0.9.3) printf '%s' de3724016885ba7c88cb8bf8b94c47682386b5f5 ;;
  esac
}

localnet_dir() {
  local version="$1" src want got
  valid_version "$version" || die "'$version' is not a Splice version like 0.9.2"
  if [ -n "${LOCALNET_DIR_OVERRIDE:-}" ]; then printf '%s' "$LOCALNET_DIR_OVERRIDE"; return; fi
  src="$LABS_CACHE/splice-$version"
  want="$(pinned_commit "$version")"
  got="$(git -C "$src" rev-parse HEAD 2>/dev/null || true)"
  if [ ! -f "$src/cluster/compose/localnet/compose.yaml" ] || { [ -n "$want" ] && [ "$got" != "$want" ]; }; then
    say "fetching the LocalNet configuration of Splice $version"
    rm -rf "$src"
    git clone -q --depth 1 --branch "$version" --filter=blob:none --sparse "$SPLICE_REPO" "$src" >&2       || die "could not fetch Splice $version from $SPLICE_REPO (the git message is above)"
    git -C "$src" sparse-checkout set cluster/compose/localnet >/dev/null
    got="$(git -C "$src" rev-parse HEAD)"
    if [ -n "$want" ] && [ "$got" != "$want" ]; then
      rm -rf "$src"
      die "Splice $version resolved to $got but these labs were tested with $want; refusing to run it"
    fi
    [ -n "$want" ] || say "Splice $version is not one of the versions these labs were tested with (commit $got)"
  fi
  printf '%s' "$src/cluster/compose/localnet"
}

localnet_compose() {
  local version="$1"; shift
  local dir; dir="$(localnet_dir "$version")"
  local extra=(-f "$LABS_ROOT/lib/compose/no-public-ports.yaml")
  [ "${LABS_NO_HOST_PORTS:-0}" = "1" ] && extra+=(-f "$LABS_ROOT/lib/compose/no-host-ports.yaml")
  [ "${LABS_CPU_LIMITS:-1}" = "1" ] && extra+=(-f "$LABS_ROOT/lib/compose/cpu-limits.yaml")
  local envs=(--env-file compose.env --env-file env/common.env)
  [ -f "$LABS_ROOT/node.env" ] && envs+=(--env-file "$LABS_ROOT/node.env")
  (cd "$dir" && IMAGE_TAG="$version" LOCALNET_DIR="$dir" docker compose -p "$LABS_PROJECT"     "${envs[@]}"     -f compose.yaml -f resource-constraints.yaml "${extra[@]}"     --profile sv --profile app-provider --profile app-user "$@") 2> >(grep -v 'level=warning' >&2)
}

localnet_up() {
  local version="$1"
  say "starting LocalNet $version (first start pulls about 2 GB of images and takes 3 to 5 minutes)"
  state_set localnet-version "$version"
  localnet_start "$version"
  ensure_node_ready || die "LocalNet $version did not become ready; ./lab status and docker logs splice show why"
  if [ "$(container_health splice)" = healthy ]; then
    localnet_compose "$version" up -d --no-deps nginx >/dev/null 2>&1 \
      || say "nginx did not start, so the browser UIs on localhost are unavailable; the labs do not need them"
  fi
}

localnet_start() {
  local version="$1" all services log rc=0
  local -a list
  all="$(localnet_compose "$version" config --services)" || die "could not read the services of LocalNet $version"
  services="$(printf '%s\n' "$all" | grep -v -x nginx | tr '\n' ' ' || true)"
  [ -n "${services// /}" ] || die "LocalNet $version lists no services"
  read -r -a list <<< "$services"
  mkdir -p "$LABS_STATE"
  log="$LABS_STATE/compose-up.log"
  localnet_compose "$version" up -d "${list[@]}" >"$log" 2>&1 || rc=$?
  if [ "$rc" != 0 ]; then
    if [ -z "$(docker ps -aq --filter "label=com.docker.compose.project=$LABS_PROJECT")" ]; then
      tail -n 25 "$log" >&2
      die "docker compose could not start LocalNet (exit $rc); the last lines of its output are above"
    fi
    say "docker compose reported a problem (exit $rc) and the node may still come up; its output is in $log"
  fi
}

reset_previous_localnet() {
  local fallback="$1" previous answer
  [ -n "$(docker ps -aq --filter "label=com.docker.compose.project=$LABS_PROJECT")" ] || return 0
  if [ "${LAB_YES:-0}" != "1" ]; then
    [ -t 0 ] || die "a LocalNet from a previous lab exists; run again with LAB_YES=1 to remove it and its data"
    read -r -p 'A LocalNet from a previous lab exists. Remove it and all its data? [y/N] ' answer
    [ "$answer" = "y" ] || die "left the existing LocalNet alone"
  fi
  say "removing the LocalNet left by a previous lab, with its data"
  previous="$(state_get localnet-version)"
  [ -n "$previous" ] || previous="$(running_version || true)"
  localnet_compose "${previous:-$fallback}" down -v >/dev/null
}

node_ready() {
  docker exec splice wget -q -O /dev/null http://localhost:2903/api/validator/readyz 2>/dev/null \
    && docker exec splice wget -q -O /dev/null http://localhost:5012/api/scan/readyz 2>/dev/null \
    && docker exec splice wget -q -O /dev/null http://localhost:5014/api/sv/readyz 2>/dev/null
}

wait_node_ready() {
  local seconds="${1:-600}" waited=0
  until node_ready; do
    [ "$waited" -ge "$seconds" ] && return 1
    sleep 10; waited=$((waited + 10))
  done
}

ensure_node_ready() {
  local attempt limit="${LABS_READY_TIMEOUT:-480}"
  for attempt in 1 2 3; do
    wait_node_ready "$limit" && return 0
    say "app-user's validator, Scan or the SV app is not ready after $((limit / 60)) minutes (attempt $attempt of 3), restarting splice"
    docker restart -t 60 splice >/dev/null
  done
  wait_node_ready "$limit"
}

localnet_down() {
  local version; version="$(state_get localnet-version)"
  [ -n "$version" ] || version="${1:-}"
  [ -n "$version" ] || version="$(running_version || true)"
  [ -n "$version" ] || version="$(docker container inspect splice --format '{{.Config.Image}}' 2>/dev/null | sed -n 's/.*://p' || true)"
  if [ -z "$version" ]; then say "no LocalNet from these labs is running"; return 0; fi
  localnet_compose "$version" down "${@:2}" >/dev/null
}

container_health() { docker container inspect "$1" --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' 2>/dev/null || echo missing; }
restart_count() { docker container inspect "$1" --format '{{.RestartCount}}' 2>/dev/null || echo 0; }

wait_healthy() {
  local name="$1" seconds="${2:-600}" waited=0
  while [ "$(container_health "$name")" != healthy ]; do
    [ "$waited" -ge "$seconds" ] && return 1
    sleep 10; waited=$((waited + 10))
  done
}

running_version() {
  docker exec splice wget -q -O - "http://localhost:2903/api/validator/version" 2>/dev/null \
    | sed -n 's/.*"version":"\([^"]*\)".*/\1/p'
}

pg() { docker exec postgres psql -U cnadmin -d "$1" -Atc "$2"; }

participant_id() {
  local token
  token=$(localnet_token ledger-api-user "$(node_audience "$1")")
  docker exec splice wget -q -O - --header "Authorization: Bearer $token" \
    "http://localhost:$(node_port "$1")903/api/validator/v0/admin/participant/identities" \
    | sed -n 's/^{"id":"\([^"]*\)".*/\1/p'
}

synchronizer_id() {
  docker exec splice wget -q -O - --post-data '{}' --header 'Content-Type: application/json' \
    http://localhost:5012/api/scan/v0/amulet-rules \
    | grep -o '"activeSynchronizer":"[^"]*"' | head -1 | cut -d'"' -f4
}

traffic_purchased() {
  docker exec splice wget -q -O - "http://localhost:5012/api/scan/v0/domains/$(synchronizer_id)/members/$1/traffic-status" \
    | grep -o '"total_purchased":[0-9]*' | cut -d: -f2
}
