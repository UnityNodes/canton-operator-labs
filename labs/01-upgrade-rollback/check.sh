#!/usr/bin/env bash
. "$(cd "$(dirname "$0")/../.." && pwd)/lib/common.sh"
. "$LABS_ROOT/lib/localnet.sh"
. "$LABS_ROOT/lib/localnet-api.sh"

FROM="$(state_get lab01-from)"
[ -n "$FROM" ] || die "run ./lab 01 setup first"
[ "$(state_get lab01-broken)" = 1 ] || die "run ./lab 01 break first; there is nothing to fix yet"
failed=0
pass() { ok "$1"; }
fail() { bad "$1"; failed=1; }

say "checking the node"
for c in postgres canton; do
  [ "$(container_health "$c")" = healthy ] && pass "$c is healthy" || fail "$c is $(container_health "$c")"
done
node_ready && pass "app-user's validator, Scan and the SV app answer as ready" || fail "app-user's validator, Scan or the SV app is not ready"

before="$(restart_count splice)"; sleep "${LAB01_STABLE_SECONDS:-60}"; after="$(restart_count splice)"
[ "$before" = "$after" ] && pass "splice did not restart in the last ${LAB01_STABLE_SECONDS:-60}s" || fail "splice restarted $((after - before)) time(s) while this check watched"

version="$(running_version || true)"
[ "$version" = "$FROM" ] && pass "validator apps run $FROM" || fail "validator apps report '${version:-nothing}', expected $FROM"

want_p="$(state_get lab01-participant-rank)"; got_p="$(pg participant-app-user 'SELECT max(installed_rank) FROM participant.flyway_schema_history' 2>/dev/null || true)"
want_v="$(state_get lab01-validator-rank)"; got_v="$(pg validator-app-user 'SELECT max(installed_rank) FROM validator.flyway_schema_history' 2>/dev/null || true)"
[ "$got_p" = "$want_p" ] && pass "participant schema is the $FROM schema (migration $got_p)" || fail "participant schema is at migration ${got_p:-?}, $FROM expects $want_p"
[ "$got_v" = "$want_v" ] && pass "validator app schema is the $FROM schema (migration $got_v)" || fail "validator app schema is at migration ${got_v:-?}, $FROM expects $want_v"

errors="$(docker logs canton --since 3m 2>&1 | grep -c 'does not exist' || true)"
[ "$errors" = "0" ] && pass "no schema errors in the participant log for 3 minutes" || fail "$errors schema error(s) in the participant log in the last 3 minutes"

want_b="$(state_get lab01-balance)"; got_b="$(wallet_balance app-user 2>/dev/null || true)"
if [ -n "$got_b" ] && awk -v a="$got_b" -v b="$want_b" 'BEGIN { d = a - b; if (d < 0) d = -d; exit !(d < 1) }'; then
  pass "app-user holds $got_b CC, as before the upgrade"
else
  fail "app-user holds '${got_b:-nothing}' CC, before the upgrade it held $want_b"
fi

v_dump="$(ls -t "$LABS_ROOT"/backups/*validator-app-user* 2>/dev/null | tail -1 || true)"
p_dump="$(ls -t "$LABS_ROOT"/backups/*participant-app-user* 2>/dev/null | tail -1 || true)"
if [ -n "$v_dump" ] && [ -n "$p_dump" ]; then
  if [ "$v_dump" -ot "$p_dump" ]; then pass "the validator app backup was taken before the participant backup"
  else printf '  \033[33mNOTE\033[0m the participant backup is older than the validator app backup; with nodes running that order is unsafe\n'; fi
fi

echo
if [ "$failed" = 0 ]; then
  say "lab 01 passed"
  printf 'lab=01-upgrade-rollback result=pass from=%s to=%s splice_restarts=%s at=%s\n' "$FROM" "$(state_get lab01-to)" "$after" "$(date -u +%FT%TZ)"
else
  say "not fixed yet"; exit 1
fi
