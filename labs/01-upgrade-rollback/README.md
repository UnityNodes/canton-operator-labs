# Roll back an upgrade that has already migrated the databases

You upgrade your validator to a new Splice release. Shortly after, the release
has to be backed out, and someone rolls back the way that looks obvious: set the
version back and start the node again. The containers come up. The participant
even reports healthy. The node is still broken.

In this lab you take the backups an upgrade needs, live through that rollback,
work out what is wrong, and bring the node back to the old version with its data.

**Time:** 30 to 45 minutes, most of it waiting for nodes to start.
**Versions:** Splice 0.8.4 to 0.9.2 by default (`LAB01_FROM`, `LAB01_TO`).

## The docs you work from

- [Validator backups](https://docs.canton.network/global-synchronizer/production-operations/validator-backups)
- [Upgrade to a new release](https://docs.canton.network/global-synchronizer/production-operations/upgrade-canton-nodes)
- [Validator disaster recovery](https://docs.canton.network/global-synchronizer/production-operations/validator-disaster-recovery)
- [Validator upgrades](https://docs.canton.network/global-synchronizer/production-operations/validator-upgrades)

## Steps

1. `./lab 01 setup` starts LocalNet on the old version and gives `app-user` some
   Canton Coin. That balance is the data your rollback has to keep.
2. Take your backups into `backups/`, as the backup page tells an operator to.
   LocalNet keeps every node's database in one Postgres container called
   `postgres`, user `cnadmin`. `setup` prints the command that lists them.
3. `./lab 01 break` upgrades the node properly, then rolls it back the wrong way.
4. Find out what is wrong and fix it.
5. `./lab 01 check`.

## What `check` verifies

- `postgres`, `canton` and `splice` are healthy, and `splice` does not restart
  for a minute.
- The validator apps report the old version.
- The participant's and the validator app's database schemas are the old
  version's schemas, read from Flyway's history table.
- No schema errors in the participant log for three minutes.
- `app-user` holds the balance it had before the upgrade.
- If your backups are in `backups/`, it notes whether the validator app backup
  was taken before the participant backup.

## Hints

Open one at a time.

<details>
<summary>1. Where to look</summary>

`./lab status` shows the containers. Compare `docker inspect splice` with
`docker inspect canton`: one of them keeps restarting. Then read
`docker logs canton` for errors, not only the health status.
</details>

<details>
<summary>2. What the error means</summary>

The new release ran its database migrations when it started. The old binary
does not refuse a schema that is newer than it knows; it starts, and then its
queries fail against tables that no longer look the way it expects. The upgrade
page says it directly: once a migration has started it cannot be rolled back,
you restore the old version from backups.
</details>

<details>
<summary>3. How to restore</summary>

Stop the application containers first (`splice`, then `canton`). For each
database you backed up, drop it, create it empty, and load your dump into it
(`pg_restore` for a custom-format dump, `psql` for plain SQL). Start `canton`,
wait until it is healthy, then start `splice`. A node that hangs on its first
start after a restore usually comes up after one restart.
</details>

<details>
<summary>4. Why the backup order matters</summary>

With nodes running, the validator app's backup must be taken strictly before the
participant's. Taken the other way round, the app's database can describe
transactions the restored participant has never seen. On LocalNet you also run
the synchronizer, so you back up and restore its databases too; a real validator
only has its own two.
</details>

## Clean up

`./lab down` stops LocalNet and deletes its volumes. Your `backups/` stay.
