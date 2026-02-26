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

## Available Agents

Agents are interactive workflows that walk you through multi-step tasks. They use skills as their knowledge base.

| Agent              | Description                                            | Example prompts                                                                                                    |
| ------------------ | ------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------ |
| `pipeline-builder` | Build and deploy pipelines interactively               | "I want to index all Jupiter swap events on Solana into my Postgres database"                                      |
| `dataset-finder`   | Quick dataset lookups with ready-to-paste YAML         | "What's the right dataset for tracking NFT transfers on Polygon?"                                                  |
| `pipeline-doctor`  | Diagnose and fix broken pipelines                      | "My pipeline base-usdc-transfers is stuck in error state, can you help?"                                           |

### When to use agents vs skills

- **Agents** — Use when you want interactive help: building something, diagnosing a problem, or getting a quick answer.
- **Skills** — Used automatically by agents as reference material. You can also invoke them directly for documentation lookup (e.g., "what's the YAML syntax for a postgres sink?").

## Usage

Describe what you want in natural language and the right agent or skill will be selected automatically:

> "I want to index all Jupiter swap events on Solana into my Postgres database" → `@pipeline-builder`

> "What's the right dataset for tracking NFT transfers on Polygon?" → `@dataset-finder`

> "My pipeline base-usdc-transfers is stuck in error state, can you help?" → `@pipeline-doctor`

> "What's the YAML syntax for a postgres sink?" → `turbo-pipelines` skill

> "How do I pause a pipeline?" → `turbo-lifecycle` skill

> "I need a TypeScript transform to categorize transactions by value" → `turbo-transforms` skill

## What's Covered

These skills cover the full Goldsky Turbo pipeline surface:

- **Sources** — 130+ chain datasets (EVM, Solana, Bitcoin, Stellar, Sui, NEAR, Starknet, Fogo), source-level filtering, bounded ranges
- **Transforms** — SQL (DataFusion), TypeScript/WASM scripts, dynamic tables (postgres/in-memory), external HTTP handlers, Solana-specific decoders
- **Sinks** — PostgreSQL, PostgreSQL Aggregate, ClickHouse, Kafka, S3, Webhook, S2, Blackhole (testing)
- **Modes** — Streaming (continuous) and Job (one-time batch with `end_block`)
- **Lifecycle** — Deploy, list, pause, resume, restart, delete
- **Monitoring** — Live inspect TUI, log analysis, error pattern matching

## Prerequisites

**None required!** The skills will guide you through setup if needed.

The `goldsky-auth-setup` skill helps you install the Goldsky CLI, log in, and select a project.

## Documentation

- [Goldsky Docs](https://docs.goldsky.com)
- [Turbo Pipelines Guide](https://docs.goldsky.com/turbo-pipelines/introduction)
- [CLI Reference](https://docs.goldsky.com/turbo-pipelines/cli)

## License

MIT
