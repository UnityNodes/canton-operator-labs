#!/usr/bin/env bash
. "$(cd "$(dirname "$0")/../.." && pwd)/lib/common.sh"
. "$LABS_ROOT/lib/localnet.sh"
. "$LABS_ROOT/lib/localnet-api.sh"

VERSION="${LAB02_VERSION:-0.9.2}"
valid_version "$VERSION" || die "LAB02_VERSION must be a Splice version like 0.9.2"

reset_previous_localnet "$VERSION"
rm -rf "$LABS_STATE"
cat > "$LABS_ROOT/node.env" <<ENV
TARGET_TRAFFIC_THROUGHPUT=20000
ENV

localnet_up "$VERSION"
say "giving app-user Canton Coin to pay for traffic"
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
participant="$(participant_id app-user || true)"
[ -n "$participant" ] || die "could not read app-user's participant id; ./lab status and docker logs splice show why"
state_set lab02-version "$VERSION"
state_set lab02-participant "$participant"

cat <<MSG

LocalNet runs Splice $VERSION. app-user's validator holds $balance CC and buys
synchronizer traffic automatically. Its settings are in $LABS_ROOT/node.env,
the way a docker-compose validator keeps them in .env.

Next, someone changes those settings during maintenance and the validator's
app gets busy. Run: ./lab 02 break
MSG
