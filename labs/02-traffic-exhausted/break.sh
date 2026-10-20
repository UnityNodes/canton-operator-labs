#!/usr/bin/env bash
. "$(cd "$(dirname "$0")/../.." && pwd)/lib/common.sh"
. "$LABS_ROOT/lib/localnet.sh"
. "$LABS_ROOT/lib/localnet-api.sh"

VERSION="$(state_get lab02-version)"
[ -n "$VERSION" ] || die "run ./lab 02 setup first"

say "maintenance: a settings change is applied and the validator restarted"
cat > "$LABS_ROOT/node.env" <<ENV
TARGET_TRAFFIC_THROUGHPUT=0
ENV
localnet_compose "$VERSION" up -d --no-deps splice >/dev/null
ensure_splice_healthy || die "splice did not come back after the settings change"

say "the app gets busy: app-user submits transactions until the node refuses them"
sent=0
refused=0
for _ in $(seq 1 800); do
  if wallet_call app-user POST wallet/tap '{"amount":"1"}' >/dev/null 2>&1; then
    sent=$((sent + 1)); refused=0
  else
    refused=$((refused + 1))
    [ "$refused" -ge 3 ] && break
  fi
done
[ "$refused" -ge 3 ] || die "the node accepted 800 transactions without running out of traffic; is top-up really off?"
state_set lab02-purchased "$(traffic_purchased "$(state_get lab02-participant)")"

cat <<MSG

app-user sent $sent transactions, and now every new one fails. Users report
that their transfers hang and then come back as errors.

Find out why the node refuses transactions, get it working again, and make
sure it cannot happen again the same way. These pages are what an operator has:

  https://docs.canton.network/global-synchronizer/deployment/synchronizer-traffic
  https://docs.canton.network/global-synchronizer/deployment/validator-docker-compose
  https://docs.canton.network/global-synchronizer/troubleshooting-guide/transaction-failures

The node's settings are in $LABS_ROOT/node.env. Apply a change with:

  ./lab compose up -d --no-deps splice

When you think it is fixed, run: ./lab 02 check
MSG
