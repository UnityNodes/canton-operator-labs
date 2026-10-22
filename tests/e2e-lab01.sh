#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
. lib/common.sh
. lib/localnet.sh

LAB_YES=1 ./lab 01 setup
dbs=$(docker exec postgres psql -U cnadmin -d postgres -Atc "SELECT datname FROM pg_database WHERE datname NOT IN ('postgres','template0','template1') ORDER BY (datname LIKE 'validator-%') DESC, (datname LIKE 'participant-%') DESC, datname")
for db in $dbs; do docker exec postgres pg_dump -U cnadmin -Fc "$db" > "backups/$db.dump"; sleep 1; done

LAB_YES=1 ./lab 01 break
sleep 60
if out="$(./lab 01 check 2>&1)"; then echo "e2e: check passed on the broken node, which it must not"; exit 1; fi
printf '%s\n' "$out" | grep -q FAIL || { echo "e2e: check failed without reporting a FAIL line"; printf '%s\n' "$out"; exit 1; }

docker stop -t 60 splice canton >/dev/null
for f in backups/*.dump; do
  db=$(basename "$f" .dump)
  docker exec postgres psql -U cnadmin -d postgres -qc "DROP DATABASE \"$db\" WITH (FORCE)"
  docker exec postgres psql -U cnadmin -d postgres -qc "CREATE DATABASE \"$db\""
  docker exec -i postgres pg_restore -U cnadmin -d "$db" --no-owner < "$f"
done
docker start canton >/dev/null
wait_healthy canton 600
docker start splice >/dev/null
ensure_node_ready
./lab 01 check
echo "e2e: lab 01 passed"
