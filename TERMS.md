# Terms of Use — Goldsky Agent plugin

_Last updated: 2026-09-16_

These terms cover the **Goldsky Agent plugin** (this repository) as distributed
through the Claude Code and Cursor plugin marketplaces.

## License

The plugin is open source under the [MIT License](./LICENSE). You may use,
copy, modify, and redistribute it on those terms. The plugin is free; we do not
charge for access to or use of it.

## What you are getting

Skill documents, an agent definition, and hook scripts that help an AI coding
agent work with Goldsky. The plugin is **instructional content**, not a service.

## Use of the Goldsky platform

The plugin helps you drive Goldsky, but it is not the product. Your use of the
Goldsky platform, CLI, and APIs is governed separately by the Goldsky Terms of
Service at <https://goldsky.com/terms>. You need your own Goldsky account.

## Review what the agent does

The plugin instructs an AI agent to run commands — including commands that
**deploy pipelines, create resources, and in the case of the Compose skills,
send onchain transactions that spend real funds and gas**. Model output is not
deterministic and can be wrong.

You are responsible for what runs on your machine and in your account. Review
generated pipeline YAML, contract addresses, and transactions before applying
them. The bundled pre-deploy hooks are a safety net, not a guarantee — a passing
validation checks shape, not correctness.

## No warranty

Provided "as is", without warranty of any kind, as set out in the MIT License.
To the maximum extent permitted by law, Goldsky is not liable for any damages
arising from use of the plugin — including losses from deployed pipelines,
deployed contracts, or onchain transactions.

## Support

Best-effort via GitHub issues at
<https://github.com/goldsky-io/goldsky-agent/issues>, or <support@goldsky.com>.
We aim to address security and stability reports promptly.

## Changes

We may update these terms; material changes will be noted in the repository
history. Continued use after a change means you accept it.
