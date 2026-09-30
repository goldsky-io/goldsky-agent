---
name: get-started
description: Set up Goldsky after a fresh install and take the first useful step
---

The user just installed Goldsky and wants to get started. Say so, then do this in order.

1. Read `skills/auth-setup/SKILL.md` and install any missing CLI components with its bundled installer. Do not ask the user to run `curl`, enter a sudo password, or install binaries themselves.

2. On every later command, restore PATH:

```bash
export PATH="$HOME/.local/bin:$HOME/.goldsky/bin:$PATH"
```

3. Run `goldsky project list`. A project table means they are already logged in. If the output says to run `goldsky login`, stop and tell them to run this one command in their own terminal:

```bash
goldsky login
```

The browser has to be on the same machine as that command. Do not ask for an API token, do not pass `--token`, and do not use a host-specific question tool. When they say they are done, run `goldsky project list` again. If it still says they are not logged in, ask them to run `goldsky login` again.

4. Report the CLI version and the active project. Then ask what onchain data they want. Offer one starting point: name a chain and an event (for example USDC transfers on Base), find the matching dataset, and draft a pipeline only after they agree. Do not create secrets, pipelines, or deployments until they say yes.
