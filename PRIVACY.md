# Privacy Policy — Goldsky Agent plugin

_Last updated: 2026-09-16_

This policy covers the **Goldsky Agent plugin** (this repository) as distributed
through the Claude Code and Cursor plugin marketplaces. Goldsky's product-wide
policy is at <https://goldsky.com/privacy>.

## What the plugin is

The plugin is a set of Markdown skill files, an agent definition, and three
shell hooks. It contains no compiled code, no binaries, no telemetry, and no
network client of its own.

## What we collect

**Nothing.** The plugin collects, stores, and transmits no data. It has no
analytics, no crash reporting, and no phone-home. We receive nothing when you
install or use it.

## What the plugin causes to happen on your machine

Being honest about the parts that do touch the network or your filesystem:

| Component | Behavior |
| --- | --- |
| `goldsky-docs` MCP server | The manifests declare an HTTP MCP server at `https://docs.goldsky.com/mcp`. Your agent sends documentation queries there. It is unauthenticated and serves public documentation only. |
| Skill instructions | Skills instruct your agent to run `goldsky` CLI commands locally. Those commands talk to the Goldsky API using credentials already on your machine, exactly as if you had typed them. |
| Hooks | `pre-deploy-validate`, `secret-check`, and `post-deploy-inspect` run locally when your agent runs a `goldsky turbo apply`. They read the pipeline YAML you are deploying and run `goldsky turbo validate` / `goldsky secret list`. They transmit nothing and write nothing to disk. |

## Credentials

The plugin never reads, stores, transmits, or logs your Goldsky API token.
Authentication is handled entirely by the `goldsky` CLI, which persists
credentials to `~/.goldsky/auth_token` under your control.

The skills are written to instruct agents **never to ask you to paste a token
into a chat transcript** — see `skills/auth-setup/SKILL.md`. If any skill in
this repository ever does ask for a token in chat, that is a bug; please report
it.

## Third parties

We share nothing, because we collect nothing. We do not sell data and we do not
use anything from your use of this plugin to train models.

## Contact

Questions or a privacy concern: <support@goldsky.com>. Security issues: see
[SECURITY.md](./SECURITY.md).
