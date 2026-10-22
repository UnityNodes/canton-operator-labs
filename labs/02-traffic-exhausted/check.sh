#!/usr/bin/env bash
. "$(cd "$(dirname "$0")/../.." && pwd)/lib/common.sh"
. "$LABS_ROOT/lib/localnet.sh"
. "$LABS_ROOT/lib/localnet-api.sh"

VERSION="$(state_get lab02-version)"
[ -n "$VERSION" ] || die "run ./lab 02 setup first"
failed=0
pass() { ok "$1"; }
fail() { bad "$1"; failed=1; }

say "checking the node"
node_ready && pass "app-user's validator, Scan and the SV app answer as ready" || fail "app-user's validator, Scan or the SV app is not ready"

target="$(docker exec splice printenv TARGET_TRAFFIC_THROUGHPUT 2>/dev/null || true)"
if [ -n "$target" ] && [ "$target" -gt 0 ] 2>/dev/null; then
  pass "automatic top-up is on in the running validator (target throughput $target bytes/s)"
else
  fail "automatic top-up is off in the running validator (target throughput '${target:-unset}'), so this will happen again"
fi

at_break="$(state_get lab02-purchased)"
now="$(traffic_purchased "$(state_get lab02-participant)" 2>/dev/null || true)"
if [ -n "$now" ] && [ -n "$at_break" ] && [ "$now" -gt "$at_break" ]; then
  pass "app-user's validator bought traffic since the incident ($at_break -> $now bytes purchased)"
else
  fail "no traffic bought since the incident (${now:-?} bytes purchased, ${at_break:-?} at the incident); base-rate traffic coming back on its own is not a fix"
fi

load="$(state_get lab02-sent)"
case "$load" in ''|*[!0-9]*) load=100 ;; esac
[ "$load" -lt 20 ] && load=20
[ "$load" -gt 200 ] && load=200
refused=0
for _ in $(seq 1 "$load"); do
  if wallet_call app-user POST wallet/tap '{"amount":"1"}' >/dev/null 2>&1; then
    refused=0
  else
    refused=$((refused + 1))
    [ "$refused" -ge 3 ] && break
  fi
done
if [ "$refused" -lt 3 ]; then
  pass "app-user sent $load transactions in a row, about the load that stopped it before, and none was held back"
else
  fail "the node refused app-user's transactions again under the same load"
fi

echo
if [ "$failed" = 0 ]; then
  say "lab 02 passed"
  printf 'lab=02-traffic-exhausted result=pass version=%s purchased=%s at=%s\n' "$VERSION" "$now" "$(date -u +%FT%TZ)"
else
  say "not fixed yet"; exit 1
fi
