#!/usr/bin/env bash

localnet_dir() {
  local version="$1"
  if [ -n "${LOCALNET_DIR_OVERRIDE:-}" ]; then printf '%s' "$LOCALNET_DIR_OVERRIDE"; return; fi
  local src="$LABS_CACHE/splice-$version"
  if [ ! -f "$src/cluster/compose/localnet/compose.yaml" ]; then
    say "fetching the LocalNet configuration of Splice $version"
    rm -rf "$src"
    git clone -q --depth 1 --branch "$version" --filter=blob:none --sparse "$SPLICE_REPO" "$src" 2>/dev/null \
      || die "could not fetch Splice $version from $SPLICE_REPO"
    git -C "$src" sparse-checkout set cluster/compose/localnet >/dev/null
  fi
  printf '%s' "$src/cluster/compose/localnet"
}

localnet_compose() {
  local version="$1"; shift
  local dir; dir="$(localnet_dir "$version")"
  local extra=()
  [ "${LABS_NO_HOST_PORTS:-0}" = "1" ] && extra+=(-f "$LABS_ROOT/lib/compose/no-host-ports.yaml")
  [ "${LABS_CPU_LIMITS:-1}" = "1" ] && extra+=(-f "$LABS_ROOT/lib/compose/cpu-limits.yaml")
  local envs=(--env-file compose.env --env-file env/common.env)
  [ -f "$LABS_ROOT/node.env" ] && envs+=(--env-file "$LABS_ROOT/node.env")
  (cd "$dir" && IMAGE_TAG="$version" LOCALNET_DIR="$dir" docker compose -p "$LABS_PROJECT" \
    "${envs[@]}" \
    -f compose.yaml -f resource-constraints.yaml "${extra[@]}" \
    --profile sv --profile app-provider --profile app-user "$@") 2> >(grep -v 'level=warning' >&2)
}

localnet_up() {
  local version="$1"
  say "starting LocalNet $version (first start pulls about 2 GB of images and takes 3 to 5 minutes)"
  state_set localnet-version "$version"
  localnet_start "$version"
  ensure_node_ready || die "LocalNet $version did not become ready; ./lab status and docker logs splice show why"
  if [ "$(container_health splice)" = healthy ]; then
    timeout 300 localnet_compose "$version" up -d nginx >/dev/null 2>&1 || true
  fi
}

localnet_start() {
  local version="$1" services
  local -a list
  services="$(localnet_compose "$version" config --services 2>/dev/null | grep -v -x nginx | tr '\n' ' ')"
  [ -n "$services" ] || die "could not read the LocalNet $version services"
  read -r -a list <<< "$services"
  localnet_compose "$version" up -d "${list[@]}" >/dev/null 2>&1 || true
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
  [ -n "$version" ] || version="$(docker inspect splice --format '{{.Config.Image}}' 2>/dev/null | sed -n 's/.*://p')"
  [ -n "$version" ] || die "no LocalNet from these labs is running and none is recorded in $LABS_STATE"
  localnet_compose "$version" down "${@:2}" >/dev/null
}

container_health() { docker inspect "$1" --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' 2>/dev/null || echo missing; }
restart_count() { docker inspect "$1" --format '{{.RestartCount}}' 2>/dev/null || echo 0; }

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
