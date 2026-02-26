# Goldsky Agent

AI skills for streaming real-time blockchain data to your infrastructure. Build, deploy, and debug data pipelines that index onchain events from 130+ chains into PostgreSQL, ClickHouse, Kafka, and more.

## Installation

### Option 1: Claude Code Plugin (Recommended)

Install via the plugin marketplace. This is the recommended method — it handles version control and delivers updates automatically so your skills stay current.

```
/plugin marketplace add goldsky-io/goldsky-agent
/plugin install goldsky@goldsky-agent
```

### Option 2: Load from Local Directory

Clone the repo and point Claude Code at it directly. You'll need to `git pull` manually to get updates.

```bash
git clone https://github.com/goldsky-io/goldsky-agent.git
claude --plugin-dir ./goldsky-agent
```

### Option 3: Copy Skills Directly

Copy the skills into your project's skills directory. Works with any AI tool that supports the [SKILL.md](https://agentskills.io) format (Claude Code, Cursor, etc.). You'll need to re-copy to get updates.

```bash
git clone https://github.com/goldsky-io/goldsky-agent.git

# Claude Code
cp -r goldsky-agent/skills/* .claude/skills/

# Cursor
cp -r goldsky-agent/skills/* .cursor/skills/
```

## Available Skills

| Skill                 | Description                                                                                     |
| --------------------- | ----------------------------------------------------------------------------------------------- |
| `goldsky-auth-setup`  | Install CLI, login, and project setup                                                           |
| `goldsky-datasets`    | Discover available blockchain datasets and chains (EVM, Solana, Bitcoin, Stellar, Sui, and more) |
| `goldsky-secrets`     | Manage credentials for sinks (PostgreSQL, Kafka, ClickHouse, etc.)                              |
| `turbo-pipelines`     | Create, configure, and deploy Turbo pipelines (streaming and job mode)                          |
| `turbo-lifecycle`     | List, delete, pause, resume, and restart pipelines (streaming and job mode)                     |
| `turbo-monitor-debug` | Monitor pipelines, view logs, inspect live data, and debug issues                               |
| `turbo-architecture`  | Design pipeline data flows, choose streaming vs job mode, and select sinks                      |
| `turbo-transforms`    | Write SQL, TypeScript, dynamic table, and handler transforms                                    |

## Agents

Specialized sub-agents for common workflows. They run in their own context with access to relevant skills.

| Agent              | Model   | Description                                                                      |
| ------------------ | ------- | -------------------------------------------------------------------------------- |
| `pipeline-doctor`  | inherit | Diagnose pipeline issues — checks auth, status, logs, and error patterns         |
| `pipeline-builder` | inherit | Interactive wizard to build pipelines from chain selection through deployment     |
| `dataset-finder`   | haiku   | Quick dataset lookup — returns chain prefixes and ready-to-paste YAML snippets   |

Invoke agents directly:

> `@pipeline-doctor My pipeline is stuck in error state`

> `@pipeline-builder I need to index ERC20 transfers from Base into PostgreSQL`

> `@dataset-finder What dataset for Polygon NFTs?`

## Hooks

Automated guardrails that fire around pipeline deploys. No configuration needed — they activate when the plugin is installed.

| Hook                  | Event        | What it does                                                              |
| --------------------- | ------------ | ------------------------------------------------------------------------- |
| `pre-deploy-validate` | PreToolUse   | Runs `goldsky turbo validate` before `goldsky turbo apply`, blocks if invalid |
| `secret-check`        | PreToolUse   | Verifies all `secret_name` refs in YAML exist, blocks if missing          |
| `post-deploy-inspect` | PostToolUse  | Suggests `goldsky turbo inspect` after a successful deploy                |

Hooks require `jq` to be installed. They gracefully fall through if `jq` or the Goldsky CLI are unavailable.

## Usage

You can invoke skills by name or just describe what you want in natural language:

> "Help me deploy a pipeline that reads ERC20 transfers from Base and writes to PostgreSQL"

> "What blockchain datasets does Goldsky support?"

> "I'm getting an error in my pipeline logs, can you help debug?"

> "I need a TypeScript transform to categorize transactions by value"

> "Help me set up a dynamic table to filter by a wallet allowlist"

> "Should I use streaming or job mode for my backfill?"

The AI will automatically use the appropriate skill based on your request.

## What's Covered

These skills cover the full Goldsky Turbo pipeline surface:

- **Sources** — 130+ chain datasets (EVM, Solana, Bitcoin, Stellar, Sui, NEAR, Starknet, Fogo), source-level filtering, bounded ranges
- **Transforms** — SQL (DataFusion), TypeScript/WASM scripts, dynamic tables (postgres/in-memory), external HTTP handlers, Solana-specific decoders
- **Sinks** — PostgreSQL, PostgreSQL Aggregate, ClickHouse, Kafka, S3, Webhook, S2, Blackhole (testing)
- **Modes** — Streaming (continuous) and Job (one-time batch with `end_block`)
- **Lifecycle** — Deploy, list, pause, resume, restart, delete
- **Monitoring** — Live inspect TUI, log analysis, error pattern matching
- **Agents** — Pipeline diagnostics, interactive builder wizard, dataset lookup
- **Hooks** — Pre-deploy validation, secret verification, post-deploy suggestions

## Prerequisites

**None required!** The skills will guide you through setup if needed.

The `goldsky-auth-setup` skill helps you install the Goldsky CLI, log in, and select a project.

## Documentation

- [Goldsky Docs](https://docs.goldsky.com)
- [Turbo Pipelines Guide](https://docs.goldsky.com/turbo-pipelines/introduction)
- [CLI Reference](https://docs.goldsky.com/turbo-pipelines/cli)

## License

MIT
