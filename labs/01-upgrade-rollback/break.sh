#!/usr/bin/env bash
. "$(cd "$(dirname "$0")/../.." && pwd)/lib/common.sh"
. "$LABS_ROOT/lib/localnet.sh"

FROM="$(state_get lab01-from)"; TO="$(state_get lab01-to)"
[ -n "$FROM" ] || die "run ./lab 01 setup first"

if ! ls "$LABS_ROOT"/backups/* >/dev/null 2>&1; then
  printf 'There is nothing in %s/backups/. Without backups this lab cannot be fixed.\n' "$LABS_ROOT"
  if [ "${LAB_YES:-0}" != "1" ]; then
    read -r -p 'Break it anyway? [y/N] ' answer
    [ "$answer" = "y" ] || exit 1
  fi
fi

say "upgrading to $TO: the $TO bundle's compose files and IMAGE_TAG, databases kept"
localnet_compose "$FROM" down >/dev/null
localnet_up "$TO" tolerate-unhealthy
up=0
for attempt in 1 2 3; do
  wait_healthy splice 600 && { up=1; break; }
  say "splice is not healthy after 10 minutes (attempt $attempt): $(docker inspect splice --format '{{range .State.Health.Log}}{{.Output}}{{end}}' 2>/dev/null | tail -c 160 | tr '\n' ' ')"
  docker restart -t 60 splice >/dev/null
done
[ "$up" = 1 ] || die "the upgrade to $TO did not come up; ./lab status and docker logs splice show why"
say "upgrade done: the validator apps report $(running_version)"

say "the incident: $TO has to be backed out, and someone sets the version back to $FROM"
localnet_compose "$TO" down >/dev/null
localnet_compose "$FROM" up -d >/dev/null 2>&1 || true
state_set localnet-version "$FROM"

cat <<MSG

The node was set back to $FROM by changing the version and starting it again.
Look at it. Something is wrong, and it is not obvious from the container list.

Bring the node back to a working $FROM with app-user's balance from before the
upgrade. These pages are what an operator has for this:

  https://docs.canton.network/global-synchronizer/production-operations/upgrade-canton-nodes
  https://docs.canton.network/global-synchronizer/production-operations/validator-disaster-recovery

The compose command these labs use is:

  docker compose -p $LABS_PROJECT ... (run ./lab status to see the containers)

When you think it is fixed, run: ./lab 01 check
MSG
