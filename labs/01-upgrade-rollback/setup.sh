#!/usr/bin/env bash
. "$(cd "$(dirname "$0")/../.." && pwd)/lib/common.sh"
. "$LABS_ROOT/lib/localnet.sh"
. "$LABS_ROOT/lib/localnet-api.sh"

FROM="${LAB01_FROM:-0.8.4}"
TO="${LAB01_TO:-0.9.2}"

if [ -n "$(docker ps -aq --filter "label=com.docker.compose.project=$LABS_PROJECT")" ]; then
  say "removing the LocalNet left by a previous lab, with its data"
  previous="$(state_get localnet-version)"
  [ -n "$previous" ] || previous="$(running_version || true)"
  localnet_compose "${previous:-$FROM}" down -v >/dev/null
fi
rm -rf "$LABS_STATE"

localnet_up "$FROM"
say "giving app-user some Canton Coin, so there is data the rollback must keep"
balance=0
for _ in $(seq 1 36); do
  wallet_call app-user POST wallet/tap '{"amount":"250"}' >/dev/null 2>&1 || { sleep 10; continue; }
  for _ in $(seq 1 15); do
    balance="$(wallet_balance app-user 2>/dev/null || true)"
    [ -n "$balance" ] && [ "${balance%%.*}" -gt 0 ] && break 2
    sleep 2
  done
done
[ "${balance%%.*}" -gt 0 ] || die "app-user received no Canton Coin within 6 minutes; check ./lab status"

state_set lab01-from "$FROM"
state_set lab01-to "$TO"
state_set lab01-balance "$balance"
state_set lab01-participant-rank "$(pg participant-app-user 'SELECT max(installed_rank) FROM participant.flyway_schema_history')"
state_set lab01-validator-rank "$(pg validator-app-user 'SELECT max(installed_rank) FROM validator.flyway_schema_history')"

cat <<MSG

LocalNet runs Splice $FROM. app-user holds $balance CC.

Your node is about to be upgraded to $TO. Before that, take the backups you
would need to undo it, the way the validator backup page describes, and put
them in $LABS_ROOT/backups/.

  https://docs.canton.network/global-synchronizer/production-operations/validator-backups

LocalNet keeps every node's database in one Postgres container named postgres
(user cnadmin). The databases are listed by:

  docker exec postgres psql -U cnadmin -d postgres -Atc "SELECT datname FROM pg_database WHERE datname NOT IN ('postgres','template0','template1')"

When your backups are in place, run: ./lab 01 break
MSG
