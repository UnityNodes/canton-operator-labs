# Contributing

Thanks for helping. The most useful things you can send are a report of a lab that did not work for you and an idea for the next incident to practise.

## Report a problem or a result

- A lab failed or a step was unclear: [open an issue](https://github.com/UnityNodes/canton-operator-labs/issues/new?template=lab-problem.yml). Include your OS, Docker version, the lab and the last lines of `docker ps -a` and the failing command.
- You finished a lab: [tell us how it went](https://github.com/UnityNodes/canton-operator-labs/issues/new?template=lab-result.yml).

## Propose a new lab

[Open a lab request](https://github.com/UnityNodes/canton-operator-labs/issues/new?template=lab-request.yml) first. The best candidates are incidents that operators actually hit and that the public docs already explain, so the lab teaches the docs instead of competing with them.

## How a lab is built

Each lab lives in `labs/NN-name/` with four scripts and a README.

| File | Job |
| --- | --- |
| `setup.sh` | Start LocalNet in the state the lab begins from and print what the learner needs to know |
| `break.sh` | Cause the incident, the way it happens in production |
| `check.sh` | Prove the node is fixed. Print PASS and FAIL lines, and one `result=pass` line at the end |
| `README.md` | The story, the docs pages to use, what `check` verifies, and hints that open one at a time |

Rules for a lab:

- LocalNet only. A lab never needs DevNet, TestNet, MainNet, or a secret of the learner's.
- `check` must prove the fix, not a recovery by waiting. If the incident clears by itself after a while, `check` has to tell the two apart. It should repeat the condition that caused the incident, not trust one probe.
- `break` records that it ran, and `check` refuses to pass without it.
- `break` verifies that the incident really happened, for example by finding the error in a log, before it tells the learner to start.
- A new Splice version is added with its commit in `pinned_commit` in `lib/localnet.sh`.
- The README links the public docs the learner should use, and every link must resolve.
- A lab has an end-to-end test in `tests/` that runs `setup`, `break`, a scripted fix and `check`, and is added to `.github/workflows/labs.yml`.
- Plain English, short sentences.

## Licenses

By contributing you agree that your code is licensed under Apache-2.0 and your lab text under CC BY 4.0.
