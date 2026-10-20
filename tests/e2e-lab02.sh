#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
. lib/common.sh
. lib/localnet.sh
. lib/localnet-api.sh

./lab 02 setup
./lab 02 break
if ./lab 02 check; then echo "e2e: check passed on the broken node, which it must not"; exit 1; fi

refusals="$(docker logs splice --since 30m 2>&1 | grep -c SEQUENCER_NOT_ENOUGH_TRAFFIC_CREDIT || true)"
[ "$refusals" -gt 0 ] || { echo "e2e: the refusal reason is not in the validator log"; exit 1; }

sed -i 's/^TARGET_TRAFFIC_THROUGHPUT=.*/TARGET_TRAFFIC_THROUGHPUT=20000/' node.env
./lab compose up -d --no-deps splice
ensure_splice_healthy
participant="$(state_get lab02-participant)"; at_break="$(state_get lab02-purchased)"
for _ in $(seq 1 30); do
  now="$(traffic_purchased "$participant" || true)"
  [ -n "$now" ] && [ "$now" -gt "$at_break" ] && break
  sleep 10
done
./lab 02 check
echo "e2e: lab 02 passed"
