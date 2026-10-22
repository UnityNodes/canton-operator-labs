# A validator that has run out of synchronizer traffic

Every transaction a validator sends to the synchronizer costs traffic. A small
free allowance refills over time; everything above it is bought with Canton Coin,
usually by the validator's own top-up automation. In this lab a maintenance
change switches that automation off, the app gets busy, and the node stops
accepting transactions. The error your users see does not say "traffic".

You find the cause, get the node working, and make sure it does not happen again.

**Time:** about 20 minutes, plus the first image pull.
**Version:** Splice 0.9.2 by default (`LAB02_VERSION`). The docs examples may show a newer image tag. Do not copy it into this lab.

## The docs you work from

- [Synchronizer traffic](https://docs.canton.network/global-synchronizer/deployment/synchronizer-traffic)
- [Validator with Docker Compose](https://docs.canton.network/global-synchronizer/deployment/validator-docker-compose#configuring-automatic-traffic-purchases), the section Configuring Automatic Traffic Purchases
- [Transaction failures](https://docs.canton.network/global-synchronizer/troubleshooting-guide/transaction-failures). It describes timeouts and a Kubernetes setting. Here the same setting lives in `node.env`.

## Steps

1. `./lab 02 setup` starts LocalNet and gives `app-user` Canton Coin. The
   validator's settings are written to `node.env` in the repository root, the
   way a docker-compose validator keeps them in `.env`. Run all `./lab`
   commands from the repository root.
2. `./lab 02 break` applies a settings change, restarts the validator, and sends
   transactions until the node refuses them.
3. Find out why and fix it. `./lab compose up -d --no-deps splice` applies a
   change to `node.env`. If `splice` then stays `starting` for more than ten
   minutes, run `docker restart splice` once (see the main README).
4. `./lab 02 check`.

## What `check` verifies

- app-user's validator, Scan and the SV app answer as ready.
- Automatic top-up is on in the running validator, so the same load does not
  stop the node again.
- The validator bought traffic after the incident. Waiting until the free
  allowance refills makes transactions work for a while, but it is not a fix,
  and `check` does not accept it.
- `app-user` can send the same load that stopped it, in a row, without three refusals.

## Hints

Open one at a time.

<details>
<summary>1. Where to look</summary>

The wallet answers with an HTTP error and the validator log says why. Search
`docker logs splice` for the reason the synchronizer gave, not for the HTTP
status the wallet returned.
</details>

<details>
<summary>2. What the error means</summary>

The Transaction failures page describes timeouts, which is a different symptom.
Here the cause is in the validator log. `SEQUENCER_NOT_ENOUGH_TRAFFIC_CREDIT` means the sequencer refused the message
because this validator has neither free nor purchased traffic left. After a few
of those the validator's circuit breaker stops submitting for 30 seconds, which
is the `ABORTED ... circuit breaker` line, and the wallet turns that into HTTP 429.
Scan shows a member's traffic at
`/api/scan/v0/domains/<synchronizer>/members/<participant>/traffic-status`.
</details>

<details>
<summary>3. Two ways to get traffic</summary>

Buy it once through the wallet's `buy-traffic-requests` endpoint (see the
transaction failures page), or turn the top-up automation back on. Only the
second stops it happening again. The docker-compose page describes
`TARGET_TRAFFIC_THROUGHPUT` and `MIN_TRAFFIC_TOPUP_INTERVAL`: the validator buys
about throughput times interval bytes whenever its balance drops below that.
The wallet also needs enough Canton Coin to pay for what it buys. app-user starts with plenty.
</details>

## Clean up

`./lab down` stops LocalNet and deletes its volumes.
