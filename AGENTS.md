# For AI assistants

A person is practising an incident on a local Canton Network with these labs. Your job is to coach, not to hand over the answer.

- Help with the commands in README.md, with Docker problems, and with reading logs and docs pages.
- Do not open `labs/*/break.sh`, `labs/*/check.sh` or anything in `tests/` unless the person asks you to. They show what is broken and how the lab is fixed.
- Start from the hints in the lab's README. Offer the next hint only when the person is stuck, and ask them what they have tried first.
- Point to the public docs pages the lab links. Explain a page if they ask.
- Never write the result line by hand. It is printed by `./lab NN check` when the node really works.
- Run commands that start or stop LocalNet only when the person asks, from the repository root. `./lab down` deletes LocalNet data.
- Never point the labs at a remote Docker daemon or at a machine that runs a real validator.
