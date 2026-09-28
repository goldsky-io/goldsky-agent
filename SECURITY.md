# Security Policy

## Reporting a vulnerability

Report security issues in this plugin to **security@goldsky.com**. Please do not
open a public GitHub issue for a vulnerability.

Include what you found, how to reproduce it, and the plugin version
(`.claude-plugin/plugin.json` → `version`). We aim to acknowledge within two
business days and to keep you updated until it is resolved.

## Scope

In scope: everything in this repository — skill instructions, the agent
definition, the hook scripts under `hooks/scripts/`, and the plugin manifests.

Of particular interest:

- **Prompt injection** in skill text that could steer an agent into unintended
  commands.
- **Hook escapes** — the hooks receive a shell command as JSON and are meant to
  inspect it, never to execute attacker-controlled input.
- **Credential exposure** — any path by which a skill or hook could cause a
  Goldsky API token to be printed, logged, or sent into a chat transcript.

Out of scope here: the Goldsky platform, CLI, and APIs. Report those through
<https://goldsky.com/security> or the same address.

## Design commitments

- The plugin ships **no binaries** and no compiled code.
- It collects **no telemetry** — see [PRIVACY.md](./PRIVACY.md).
- Hooks **fail open**: if a hook cannot parse its input or reach the CLI, it
  allows the command through rather than blocking on a bad parse.
- Skills instruct agents never to request an API token in chat.
