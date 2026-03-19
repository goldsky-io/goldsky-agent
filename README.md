# Goldsky Agent

[![Install with npx](https://img.shields.io/badge/install-npx%20skills%20add-blue)](https://github.com/goldsky-io/goldsky-agent#installation)
[![Skills](https://img.shields.io/badge/skills-17-green)](#skills)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

AI-powered tools for indexing blockchain data. Build, deploy, and debug **Turbo pipelines** and **Subgraphs** that index onchain events from 130+ chains into PostgreSQL, ClickHouse, Kafka, GraphQL APIs, and more.

## Quick Start

| I want to...                          | Use                       |
| ------------------------------------- | ------------------------- |
| Build a new pipeline                  | `/turbo-builder`          |
| Fix a broken pipeline                 | `/turbo-doctor`           |
| Deploy a subgraph                     | `/subgraph-builder`       |
| Fix a broken subgraph                 | `/subgraph-doctor`        |
| Migrate from TheGraph                 | `/subgraph-migrate`       |
| Decide: subgraph vs pipeline?         | `/subgraph-architecture`  |
| Find the right dataset name           | `/datasets`               |
| Look up YAML syntax                   | `/turbo-pipelines`        |
| Check error patterns                  | `/turbo-monitor-debug`    |

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
├── skills/
│   ├── turbo-builder/            # Step-by-step pipeline creation wizard
│   ├── turbo-doctor/             # Diagnose and fix pipeline issues
│   ├── turbo-pipelines/          # YAML configuration reference
│   ├── turbo-transforms/         # SQL, TypeScript, dynamic tables
│   ├── turbo-monitor-debug/      # Error patterns, CLI commands
│   ├── turbo-lifecycle/          # List, pause, resume, delete
│   ├── turbo-architecture/       # Pipeline design patterns
│   ├── subgraph-builder/         # Deploy subgraphs (no-code, low-code, source)
│   ├── subgraph-doctor/          # Diagnose and fix subgraph issues
│   ├── subgraph-config/          # JSON config, CLI flags, chain slugs
│   ├── subgraph-migrate/         # Migrate from TheGraph / Alchemy
│   ├── subgraph-lifecycle/       # Tags, webhooks, pause/start/delete
│   ├── subgraph-monitor-debug/   # Error patterns, stalled detection
│   ├── subgraph-architecture/    # Subgraph vs pipeline, cross-chain design
│   ├── datasets/                 # Chain prefixes, dataset types
│   ├── secrets/                  # Credential management
│   └── auth-setup/               # CLI installation, login
├── hooks/                # Pre/post deploy automation
│   └── scripts/                  # Validation, secret checking
└── .claude-plugin/       # Plugin manifest
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

```
User: "Deploy a subgraph for my NFT contract on Ethereum"
  ↓
subgraph-builder (skill — auto-triggered)
  ↓ references
subgraph-config + auth-setup
  ↓
Deployed subgraph + GraphQL endpoint
```

## Skills

### Turbo Pipeline Skills

| Skill | Type | When to use |
| ----- | ---- | ----------- |
| `turbo-builder` | Interactive | "Build a pipeline for X" — full guided workflow |
| `turbo-doctor` | Interactive | "My pipeline is broken" — diagnose and fix |
| `turbo-architecture` | Interactive | "Should I use dataset or Kafka? Fan-in or fan-out?" — design decisions |
| `turbo-pipelines` | Reference | "What's the YAML syntax for X?" — config field reference |
| `turbo-transforms` | Reference | "How do I decode EVM logs?" — SQL, TypeScript, dynamic tables |
| `turbo-monitor-debug` | Reference | "What does this error mean?" — error patterns, CLI commands |
| `turbo-lifecycle` | Reference | "How do I pause / delete?" — lifecycle command reference |

### Subgraph Skills

| Skill | Type | When to use |
| ----- | ---- | ----------- |
| `subgraph-builder` | Interactive | "Deploy a subgraph for my contract" — no-code, low-code, or source code |
| `subgraph-doctor` | Interactive | "My subgraph is stuck" — diagnose and fix |
| `subgraph-migrate` | Interactive | "Migrate from TheGraph" — IPFS hash, URL, or source migration |
| `subgraph-architecture` | Interactive | "Subgraph or pipeline?" — product selection, cross-chain design |
| `subgraph-config` | Reference | "What's the JSON config format?" — instant subgraph config, CLI flags |
| `subgraph-lifecycle` | Reference | "How do I create a tag?" — tags, webhooks, pause/start/delete |
| `subgraph-monitor-debug` | Reference | "What does this error mean?" — error patterns, stalled detection |

### Shared Skills

| Skill | Type | When to use |
| ----- | ---- | ----------- |
| `datasets` | Reference | "What's the dataset name for Polygon NFTs?" — chain prefixes, naming |
| `secrets` | Interactive | "Create credentials for PostgreSQL" — secret management |
| `auth-setup` | Interactive | "How do I install the CLI?" — installation and login |

## Pre-Deploy Hooks

The plugin runs hooks automatically on `goldsky turbo apply` commands:

| Hook | What it does |
| ---- | ------------ |
| `pre-deploy-validate` | Runs `goldsky turbo validate`, blocks on failure |
| `secret-check` | Verifies all `secret_name` references exist |
| `post-deploy-inspect` | Suggests `goldsky turbo inspect` after deploy |

## Coverage

### Turbo Pipelines
- **Sources** — 130+ chains (EVM, Solana, Bitcoin, Stellar, Sui, NEAR, Starknet), source filtering, bounded ranges
- **Transforms** — SQL, TypeScript/WASM, dynamic tables, HTTP handlers
- **Sinks** — PostgreSQL, ClickHouse, Kafka, S3, Webhook, S2
- **Modes** — Streaming (continuous) and Job (batch with `end_block`)
- **Lifecycle** — Deploy, pause, resume, restart, delete
- **Monitoring** — Live inspect TUI, log analysis, error matching

### Subgraphs
- **Deployment** — No-code wizard, low-code JSON config, source code (AssemblyScript)
- **Migration** — One-step from TheGraph (IPFS hash), Alchemy, or any GraphQL endpoint
- **Features** — eth_call enrichments, tags for zero-downtime upgrades, webhooks
- **Chains** — 200+ EVM chains supported
- **Lifecycle** — Deploy, pause, start, delete, tag, webhook management
- **Monitoring** — Log analysis, error patterns, stalled detection

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
- [Subgraphs Guide](https://docs.goldsky.com/subgraphs/introduction)
- [CLI Reference](https://docs.goldsky.com/reference/cli)

## License

MIT
