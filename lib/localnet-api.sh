#!/usr/bin/env bash

b64url() { openssl base64 -A | tr '+/' '-_' | tr -d '='; }

localnet_token() {
  local sub="$1" aud="$2"
  local header payload unsigned sig
  header=$(printf '{"alg":"HS256","typ":"JWT"}' | b64url)
  payload=$(printf '{"sub":"%s","aud":"%s"}' "$sub" "$aud" | b64url)
  unsigned="$header.$payload"
  sig=$(printf '%s' "$unsigned" | openssl dgst -sha256 -hmac "unsafe" -binary | b64url)
  printf '%s.%s' "$unsigned" "$sig"
}

node_port() {
  case "$1" in
    app-user) echo 2 ;;
    app-provider) echo 3 ;;
    sv) echo 4 ;;
    *) echo "unknown node $1" >&2; return 1 ;;
  esac
}

node_user() {
  case "$1" in
    app-user) echo app-user ;;
    app-provider) echo app-provider ;;
    sv) echo administrator ;;
  esac
}

node_audience() {
  case "$1" in
    sv) echo "https://sv.example.com" ;;
    *) echo "https://canton.network.global" ;;
  esac
}

wallet_balance() {
  wallet_call "$1" GET wallet/balance | sed -n 's/.*"effective_unlocked_qty":"\([^"]*\)".*/\1/p'
}

wallet_call() {
  local node="$1" method="$2" path="$3" body="${4:-}"
  local token prefix
  prefix=$(node_port "$node") || return 1
  token=$(localnet_token "$(node_user "$node")" "$(node_audience "$node")")
  if [ "$method" = "POST" ]; then
    docker exec splice wget -q -O - --header "Authorization: Bearer $token" --header "Content-Type: application/json" \
      --post-data "${body:-{\}}" "http://localhost:${prefix}903/api/validator/v0/${path}"
  else
    docker exec splice wget -q -O - --header "Authorization: Bearer $token" "http://localhost:${prefix}903/api/validator/v0/${path}"
  fi
}
