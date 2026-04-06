# Goldsky Agent

[![Install with npx](https://img.shields.io/badge/install-npx%20skills%20add-blue)](https://github.com/goldsky-io/goldsky-agent#installation)
[![Skills](https://img.shields.io/badge/skills-10-green)](#skills)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

AI-powered tools for streaming real-time blockchain data. Build, deploy, and debug Turbo pipelines that index onchain events from 130+ chains into PostgreSQL, ClickHouse, Kafka, and more.

## Quick Start

| I want to...                          | Use                  |
| ------------------------------------- | -------------------- |
| Build a new pipeline                  | `/turbo-builder`     |
| Fix a broken pipeline                 | `/turbo-doctor`      |
| Find the right dataset name           | `/datasets`          |
| Look up YAML syntax                   | `/turbo-pipelines`   |
| Check error patterns or CLI commands  | `/turbo-operations`  |

Just describe what you need in natural language — the right skill is selected automatically.

## Installation

**Recommended: Universal Skills Installer**

```bash
npx skills add goldsky-io/goldsky-agent
```

The installer will prompt you to select your AI agent, or specify directly:

```bash
npx skills add goldsky-io/goldsky-agent -a claude-code  # or cursor, opencode, etc.
```

Works with 30+ AI agents including Claude Code, Cursor, OpenCode, and Codex.

**Claude Code (Plugin Marketplace)**

```
/plugin marketplace add goldsky-io/goldsky-agent
/plugin install goldsky@goldsky-agent
```

<details>
<summary>Other installation methods</summary>

**Cursor (Local Plugin)**

Clone and add to Cursor settings:

```bash
git clone https://github.com/goldsky-io/goldsky-agent.git
```

Then add the path to your Cursor settings (`Settings > Cursor Settings > JSON`):

```json
{
  "plugins.local": ["/absolute/path/to/goldsky-agent"]
}
```

**Claude Code — load from local directory**

```bash
git clone https://github.com/goldsky-io/goldsky-agent.git
claude --plugin-dir ./goldsky-agent
```

**Copy skills directly (any tool)**

```bash
git clone https://github.com/goldsky-io/goldsky-agent.git
cp -r goldsky-agent/skills/* .claude/skills/    # Claude Code
cp -r goldsky-agent/skills/* .cursor/skills/    # Cursor
```

</details>

## Repository Structure

```
goldsky-agent/
├── skills/              # All skills (auto-triggered by description matching)
│   ├── turbo-builder/         # Step-by-step pipeline creation wizard
│   ├── turbo-doctor/          # Diagnose and fix pipeline issues
│   ├── turbo-pipelines/       # YAML config + architecture reference
│   ├── turbo-transforms/      # SQL, TypeScript, dynamic tables
│   ├── turbo-operations/      # Lifecycle commands, monitoring, errors
│   ├── datasets/              # Chain prefixes, dataset types
│   ├── secrets/               # Credential management
│   ├── auth-setup/            # CLI installation, login
│   ├── cli-reference/         # All valid CLI commands + flags (auto-generated)
│   └── subgraphs/             # Subgraph deploy, GraphQL endpoints, tags reference
├── scripts/             # Maintenance scripts
│   └── generate-cli-reference.js  # Regenerates cli-reference skill from installed CLI
├── hooks/               # Pre/post deploy automation
│   └── scripts/               # Validation, secret checking
└── .claude-plugin/      # Plugin manifest
```

## How It Works

**Skills** auto-trigger based on what you describe. Interactive skills guide you through processes, help make decisions, or walk you through multi-step tasks. Reference skills provide syntax lookups, command references, and documentation.

```
User: "Build me a pipeline for USDC transfers on Base"
  ↓
turbo-builder (skill — auto-triggered)
  ↓ references
turbo-pipelines + datasets + secrets
  ↓
Generated pipeline.yaml + deployment
```

## Skills

### Interactive Skills

These guide you through processes, help make decisions, or walk you through multi-step tasks:

| Skill | When to use | What it does |
| ----- | ----------- | ------------ |
| `turbo-builder` | "I want to build a pipeline for X" | Guides you chain → dataset → transforms → sink → validate → deploy |
| `turbo-doctor` | "My pipeline is broken / not getting data / output looks wrong" | Diagnoses the problem step-by-step and offers to run fixes |
| `auth-setup` | "How do I install the CLI / log in?" | Walks through CLI installation and authentication setup |
| `secrets` | "How do I create credentials for PostgreSQL / ClickHouse?" | Guides credential creation and secret management |

### Reference Skills

Look up syntax, commands, and information without a guided workflow:

| Skill | When to use | What's inside |
| ----- | ----------- | ------------- |
| `turbo-pipelines` | "What's the YAML syntax for X? Should I use dataset or Kafka?" | Config field reference + architecture decisions (source types, flow patterns, sizing) |
| `turbo-transforms` | "How do I decode EVM logs / write a SQL transform?" | SQL, TypeScript/WASM, dynamic tables, HTTP handlers |
| `turbo-operations` | "How do I pause / restart / delete? What does this error mean?" | Lifecycle commands, pipeline states, CLI monitoring, error patterns |
| `datasets` | "What's the dataset name for Polygon NFTs?" | Chain prefixes, dataset types, naming conventions |
| `cli-reference` | Consulted automatically before any `goldsky` command | All valid subcommands, arguments, and flags — generated from the installed CLI |
| `subgraphs` | "How do I deploy a subgraph / migrate from The Graph?" | Deploy paths, GraphQL endpoints, tags, webhooks, cross-chain patterns |

## Pre-Deploy Hooks

The plugin runs hooks automatically on `goldsky turbo apply` commands:

| Hook | What it does |
| ---- | ------------ |
| `pre-deploy-validate` | Runs `goldsky turbo validate`, blocks on failure |
| `secret-check` | Verifies all `secret_name` references exist |
| `post-deploy-inspect` | Suggests `goldsky turbo inspect` after deploy |

> To regenerate the CLI reference after a CLI update: `bash scripts/generate-cli-reference.js`

## Coverage

These tools cover the full Turbo pipeline surface:

- **Sources** — 130+ chains (EVM, Solana, Bitcoin, Stellar, Sui, NEAR, Starknet), source filtering, bounded ranges
- **Transforms** — SQL, TypeScript/WASM, dynamic tables, HTTP handlers
- **Sinks** — PostgreSQL, ClickHouse, Kafka, S3, Webhook, S2
- **Modes** — Streaming (continuous) and Job (batch with `end_block`)
- **Lifecycle** — Deploy, pause, resume, restart, delete
- **Monitoring** — Live inspect (`-p` flag), log analysis, error matching

## MCP Server

The plugin bundles the [Goldsky docs MCP server](https://docs.goldsky.com/mcp-server), providing real-time search across Goldsky documentation.

When installed as a plugin, the MCP server starts automatically.

<details>
<summary>Manual MCP setup</summary>

**Claude Code**

```bash
claude mcp add --transport http goldsky-docs https://docs.goldsky.com/mcp
```

**Cursor / VS Code**

Add to `.cursor/mcp.json` or `.vscode/mcp.json`:

```json
{
  "mcpServers": {
    "goldsky-docs": {
      "type": "http",
      "url": "https://docs.goldsky.com/mcp"
    }
  }
}
```

</details>

## Documentation

- [Goldsky Docs](https://docs.goldsky.com)
- [Turbo Pipelines Guide](https://docs.goldsky.com/turbo-pipelines/introduction)
- [CLI Reference](https://docs.goldsky.com/turbo-pipelines/cli)

## License

MIT
