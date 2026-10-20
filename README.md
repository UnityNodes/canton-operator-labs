# Canton operator labs

Hands-on practice for Canton validator operators. Each lab breaks a local
Canton Network the way nodes break in production, and you fix it using the
existing operator pages on [docs.canton.network](https://docs.canton.network).
A `check` step tells you when the node is really fixed.

The labs run on LocalNet, the Docker Compose network that ships with
[Splice](https://github.com/hyperledger-labs/splice): a super validator, two
validators, a synchronizer and one Postgres, all on your machine. Nothing touches
DevNet, TestNet or MainNet.

## Labs

| Lab | What you practise | Docs it uses |
| --- | --- | --- |
| [01-upgrade-rollback](labs/01-upgrade-rollback) | Back up before an upgrade, upgrade, then roll back after the upgrade has migrated the databases | validator-backups, upgrade-canton-nodes, validator-disaster-recovery |
| [02-traffic-exhausted](labs/02-traffic-exhausted) | A validator that runs out of synchronizer traffic, and how to top it up | synchronizer-traffic, validator-docker-compose, transaction-failures |

More labs will follow. Open an issue if there is an incident you want to practise.

## Requirements

- Docker with Compose v2, 16 GB of memory free for Docker, about 12 GB of disk
- bash, git, openssl, awk
- Linux or macOS. Windows works through WSL 2.

The first start pulls about 2 GB of images per Splice version from
`ghcr.io/digital-asset/decentralized-canton-sync`.

## How a lab runs

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

A lab that changes node settings keeps them in `node.env`, the way a
docker-compose validator keeps them in `.env`; `./lab compose up -d --no-deps splice`
applies a change.

Each lab's README tells the story, links the docs pages, and has hints you can
open one at a time. When `check` passes it prints one `result=pass` line you
can paste anywhere to show you did it.

## Options

| Variable | Default | Meaning |
| --- | --- | --- |
| `LABS_NO_HOST_PORTS` | `0` | `1` publishes no LocalNet port on the host, for machines where 2000-5432 are taken |
| `LABS_CPU_LIMITS` | `1` | `0` removes the CPU caps in `lib/compose/cpu-limits.yaml` (about 4 cores in total) |
| `LOCALNET_DIR_OVERRIDE` | | Use a LocalNet directory you already have, for example from a Splice release bundle |
| `LAB01_FROM`, `LAB01_TO` | `0.8.4`, `0.9.2` | The versions lab 01 upgrades between |
| `LAB02_VERSION` | `0.9.2` | The version lab 02 runs |

## How it works

`lib/localnet.sh` fetches `cluster/compose/localnet` from the Splice repository
at the version a lab needs, and runs it with the release's own compose files,
environment files and memory limits. The labs add only two optional override
files in `lib/compose/`. Scripts talk to the nodes through `docker exec`, so
they work whether or not ports are published.

## License

Code: Apache-2.0 ([LICENSE](LICENSE)). Lab text: CC BY 4.0 ([LICENSE-docs](LICENSE-docs)).

Maintained by [Unity Nodes](https://github.com/UnityNodes).
