#!/usr/bin/env bash
set -euo pipefail
. "$(cd "$(dirname "$0")/.." && pwd)/lib/localnet-api.sh"

failed=0
expect() {
  local want="$1" verdict
  shift
  if balance_kept "$@"; then verdict=keeps; else verdict=lost; fi
  [ "$verdict" = "$want" ] || { echo "FAIL balance_kept '$1' '$2' -> $verdict, expected $want"; failed=1; }
}

expect keeps 50000.0000000000 50000.0000000000
expect keeps 50570.0000000000 50000.0000000000
expect keeps 49999.5000000000 50000.0000000000
expect lost 49990.0000000000 50000.0000000000
expect lost 0.0000000000 50000.0000000000
expect lost "" 50000.0000000000
expect lost 50000.0000000000 ""

[ "$failed" = 0 ] && echo "balance_kept: all cases pass"
exit "$failed"
