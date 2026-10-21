# Canton Operator Labs

Practise real Canton validator incidents on your own machine. Each lab breaks a local Canton Network the way nodes break in production. You find the cause and fix it with the public operator docs. A check tells you when the node is really fixed.

[![labs](https://github.com/UnityNodes/canton-operator-labs/actions/workflows/labs.yml/badge.svg)](https://github.com/UnityNodes/canton-operator-labs/actions/workflows/labs.yml)
[![Code: Apache-2.0](https://img.shields.io/badge/code-Apache--2.0-blue)](LICENSE)
[![Text: CC BY 4.0](https://img.shields.io/badge/text-CC%20BY%204.0-lightgrey)](LICENSE-docs)

Everything runs on LocalNet, the Docker Compose network that ships with [Splice](https://github.com/hyperledger-labs/splice). Nothing touches DevNet, TestNet or MainNet, and you do not need a validator of your own.

## Why

Many operators meet a failed upgrade or an empty traffic balance for the first time in production. The docs describe the fix, but reading a fix is not the same as having done it. These labs give you the incident first, then the docs, then proof that you fixed it.

## Labs

| Lab | The incident | Time | Docs you work from |
| --- | --- | --- | --- |
| [01 Upgrade and rollback](labs/01-upgrade-rollback) | An upgrade has migrated the databases and has to be backed out. The obvious rollback starts the old containers, reports healthy, and is still broken. | 30 to 45 min | [Validator backups](https://docs.canton.network/global-synchronizer/production-operations/validator-backups), [Upgrade to a new release](https://docs.canton.network/global-synchronizer/production-operations/upgrade-canton-nodes), [Disaster recovery](https://docs.canton.network/global-synchronizer/production-operations/validator-disaster-recovery) |
| [02 Traffic exhausted](labs/02-traffic-exhausted) | A maintenance change switches off traffic top-up. The app gets busy and the node stops accepting transactions with an error that does not say "traffic". | about 20 min | [Synchronizer traffic](https://docs.canton.network/global-synchronizer/deployment/synchronizer-traffic), [Validator with Docker Compose](https://docs.canton.network/global-synchronizer/deployment/validator-docker-compose), [Transaction failures](https://docs.canton.network/global-synchronizer/troubleshooting-guide/transaction-failures) |

More labs will follow. [Request one](https://github.com/UnityNodes/canton-operator-labs/issues/new?template=lab-request.yml) if there is an incident you want to practise.

## Quick start

```bash
git clone https://github.com/UnityNodes/canton-operator-labs
cd canton-operator-labs
./lab list
./lab 01 setup     # start LocalNet in the state the lab begins from
./lab 01 break     # cause the incident
                   # ... you diagnose and fix it ...
./lab 01 check     # PASS lines for what is fixed, FAIL lines for what is not
./lab down         # stop LocalNet and delete its data
```

Each lab's README tells the story, links the docs pages, and has hints you can open one at a time.

## Requirements

- Docker with Compose v2, 16 GB of memory free for Docker, about 12 GB of disk
- bash, git, openssl, awk
- Linux or macOS. Windows works through WSL 2.

The first start pulls about 2 GB of images per Splice version from `ghcr.io/digital-asset/decentralized-canton-sync`.

## What you get at the end

`check` prints one line per condition. When everything passes it ends with a single result line you can paste anywhere to show you did the lab:

```text
lab=02-traffic-exhausted result=pass version=0.9.2 purchased=<number> at=<UTC time>
```

If you ran a lab, we would like to hear how it went: [report a result](https://github.com/UnityNodes/canton-operator-labs/issues/new?template=lab-result.yml). It takes a minute and tells us which steps were unclear.

## Settings

A lab that changes node settings keeps them in `node.env`, the way a docker-compose validator keeps them in `.env`. `./lab compose up -d --no-deps splice` applies a change.

| Variable | Default | Meaning |
| --- | --- | --- |
| `LABS_NO_HOST_PORTS` | `0` | `1` publishes no LocalNet port on the host, for machines where ports 2000 to 5432 are taken |
| `LABS_CPU_LIMITS` | `1` | `0` removes the CPU caps in `lib/compose/cpu-limits.yaml` (about 4 cores in total) |
| `LOCALNET_DIR_OVERRIDE` | | Use a LocalNet directory you already have, for example from a Splice release bundle |
| `LAB01_FROM`, `LAB01_TO` | `0.8.4`, `0.9.2` | The versions lab 01 upgrades between |
| `LAB02_VERSION` | `0.9.2` | The version lab 02 runs |

## Known LocalNet behaviour

After a start or restart, the `splice` container sometimes stays `starting` for good. The super validator's validator app misses its one-minute first database check while five applications boot in one JVM container, and never opens its port. Restarting the container (`docker restart splice`) brings it up. The labs do not depend on that one app: they wait for app-user's validator, Scan and the SV app, and restart `splice` up to three times if those are not ready. If you restart `splice` while fixing a lab and app-user's wallet does not answer within ten minutes, restart it once more.

## How it works

`lib/localnet.sh` fetches `cluster/compose/localnet` from the Splice repository at the version a lab needs, and runs it with the release's own compose files, environment files and memory limits. The labs add only two optional override files in `lib/compose/`. Scripts talk to the nodes through `docker exec`, so they work whether or not ports are published.

Every lab is tested end to end in CI on a stock GitHub runner: `setup`, `break`, a scripted fix, and `check`. The workflow also runs every Monday, so a Splice release that changes behaviour shows up as a red build.

## Contributing

Bug reports and new lab ideas are welcome. See [CONTRIBUTING.md](CONTRIBUTING.md).

## Not an official project

This is an independent community project. It is not a product of the Canton Foundation or Digital Asset. It runs the unmodified Splice LocalNet and links to the public documentation at [docs.canton.network](https://docs.canton.network).

## License

Code: Apache-2.0 ([LICENSE](LICENSE)). Lab text: CC BY 4.0 ([LICENSE-docs](LICENSE-docs)).

Maintained by [Unity Nodes](https://github.com/UnityNodes).
