# Goldsky Agent

[![Install with npx](https://img.shields.io/badge/install-npx%20skills%20add-blue)](https://github.com/goldsky-io/goldsky-agent#installation)
[![Skills](https://img.shields.io/badge/skills-21-green)](#skills)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

AI-powered tools for the full Goldsky product surface. Build, deploy, and debug Turbo pipelines, Mirror pipelines, Subgraphs, Compose apps, and Edge RPC — from natural-language prompts.

## Quick Start

| I want to...                                          | Use                  |
| ----------------------------------------------------- | -------------------- |
| Build a new Turbo pipeline                            | `/turbo-builder`     |
| Fix a broken Turbo pipeline                           | `/turbo-doctor`      |
| Fix a broken Mirror pipeline                          | `/mirror-doctor`     |
| Fix a broken Compose app                              | `/compose-doctor`    |
| Build / deploy a subgraph                             | `/subgraph-builder`  |
| Fix a broken / stalled subgraph                       | `/subgraph-doctor`   |
| Migrate a subgraph from The Graph                     | `/subgraph-migrate`  |
| Build a Compose app (oracle / keeper / automation)    | `/compose`           |
| Build a BTC/USD price oracle (worked example)         | `/compose-bitcoin-oracle` |
| Build onchain verifiable randomness (worked example)  | `/compose-vrf`       |
| Distribute a dividend / corporate action pro-rata     | `/compose-dividend-distribution` |
| Build a compliance-gated payment system (worked example) | `/compose-compliance-oracle` |
| Get a fast, reliable RPC endpoint                     | `/edge`              |
| Find the right dataset name                           | `/datasets`          |
| Look up Turbo YAML syntax                             | `/turbo-pipelines`   |
| Look up Compose manifest, CLI flags, or TaskContext   | `/compose-reference` |
| Set up the CLI and log in                             | `/auth-setup`        |

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
│   ├── turbo-doctor/          # Diagnose and fix Turbo pipeline issues
│   ├── turbo-pipelines/       # YAML config + architecture reference
│   ├── turbo-transforms/      # SQL, TypeScript, dynamic tables
│   ├── turbo-operations/      # Lifecycle commands, monitoring, errors
│   ├── mirror/                # Mirror pipeline deploy, operate, sources/sinks reference
│   ├── mirror-doctor/         # Diagnose and fix Mirror pipelines
│   ├── subgraph-builder/      # Author, build & deploy subgraphs; schema/mappings/manifest
│   ├── subgraph-doctor/       # Diagnose and fix failing/stalled subgraphs
│   ├── subgraph-migrate/  # Guided migration from The Graph
│   ├── compose/               # Compose app scaffolding, triggers, wallets
│   ├── compose-compliance-oracle/  # Compliance-gated payments (worked example)
│   ├── compose-doctor/        # Diagnose and fix Compose apps
│   ├── compose-reference/     # compose.yaml fields, CLI flags, TaskContext API
│   ├── edge/                  # Managed RPC capabilities, error codes, pricing
│   ├── datasets/              # Chain prefixes, dataset types
│   ├── secrets/               # Credential management
│   └── auth-setup/            # CLI installation, login
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

Skills are grouped by product. Each group has interactive workflow skills (guided, multi-step) and/or reference skills (lookup-oriented).

### Turbo pipelines

Streaming pipelines that index onchain data from 130+ chains into PostgreSQL, ClickHouse, Kafka, S3, and more.

| Skill | When to use | What it does |
| ----- | ----------- | ------------ |
| `turbo-builder` | "I want to build a pipeline for X" | Guides you chain → dataset → transforms → sink → validate → deploy |
| `turbo-doctor` | "My pipeline is broken / not getting data / output looks wrong" | Diagnoses the problem step-by-step and offers to run fixes |
| `turbo-pipelines` | "What's the YAML syntax for X? Should I use dataset or Kafka?" | Config field reference + architecture decisions (source types, flow patterns, sizing) |
| `turbo-transforms` | "How do I decode EVM logs / write a SQL transform?" | SQL, TypeScript/WASM, dynamic tables, HTTP handlers |
| `turbo-operations` | "How do I pause / restart / delete? What does this error mean?" | Lifecycle commands, pipeline states, CLI monitoring, error patterns |

### Mirror pipelines

Goldsky's original streaming pipeline product. **Prefer Turbo for new pipelines** — reach for Mirror only when you need a subgraph entity source, the one thing Turbo can't do.

| Skill | When to use | What it does |
| ----- | ----------- | ------------ |
| `mirror` | "How do I sync my subgraph to PostgreSQL? Mirror vs Turbo?" | Sources, sinks, lifecycle commands, Mirror vs Turbo guidance |
| `mirror-doctor` | "My Mirror pipeline is failing / stuck / terminated" | Runs status and log commands, identifies root cause, applies fixes |

### Subgraphs

Hosted GraphQL APIs over indexed onchain data.

| Skill | When to use | What's inside |
| ----- | ----------- | ------------- |
| `subgraph-builder` | "Build / write / deploy a subgraph; design a schema; write a mapping" | Interactive author→build→deploy; schema design, AssemblyScript mappings, manifest, instant subgraphs, performance, testing; endpoints, tags, webhooks |
| `subgraph-doctor` | "My subgraph stopped syncing / won't deploy / is throwing errors" | Diagnostic workflow: status + log checks, the `_meta` query, error-pattern matching, preventive mapping-code root causes, fixes |
| `subgraph-migrate` | "Move my subgraph off The Graph onto Goldsky" | Path selection, deploy, verify sync, migrate tags, swap endpoint |

### Compose

Offchain-to-onchain TypeScript framework for oracles, keepers, circuit breakers, and cross-chain automation. When you need to *run logic and write back onchain* — not just read data — Compose is the tool: managed gas, smart wallets, and cron / HTTP / onchain triggers.

| Skill | When to use | What it does |
| ----- | ----------- | ------------ |
| `compose` | "Build a price oracle / keeper / cross-chain bot in TypeScript" | Walks through scaffolding, task triggers (cron, HTTP, onchain), wallets, gas sponsorship |
| `compose-doctor` | "My Compose app is in error state / crashlooping" | Runs `status`, `logs`, `secret list`, `wallet list` and diagnoses |
| `compose-reference` | "What fields does `compose.yaml` accept? What's the `TaskContext` API?" | Manifest fields, every `goldsky compose` flag, TaskContext / wallet / Collection APIs |

#### Compose examples

End-to-end worked examples — each carries the full app source and walks build → wire → deploy → smoke test under your own account. Trigger one with a short prompt (e.g. "build a bitcoin price oracle", "build a VRF"); for a custom app that isn't one of these, use `/compose`.

| Skill | When to use | What it does |
| ----- | ----------- | ------------ |
| `compose-bitcoin-oracle` | "Build a BTC/USD price oracle that writes onchain" | Cron task → CoinGecko → `PriceOracle` contract via a Compose wallet; collection for history |
| `compose-vrf` | "Build a verifiable random function / onchain randomness" | Event-triggered task → drand beacon → `fulfillRandomness` on a `RandomnessConsumer` contract, verifiable by anyone |
| `compose-dividend-distribution` | "Distribute dividends / a corporate action to token holders pro-rata" | HTTP task orchestrates a Turbo job-mode pipeline to snapshot holders at a record block, then pays each pro-rata onchain (CLI-driven) |
| `compose-compliance-oracle` | "Build a compliance-gated payment system with wallet screening" | Onchain-event task → escrow contract → Webacy AML screening → oracle approve/reject callback, plus a reconcile cron; deploy-your-own (oracle-permissioned), recommended on Base Sepolia + MockUSDC |

### Edge (managed RPC)

Globally distributed, low-latency JSON-RPC for EVM chains, built on eRPC — a drop-in replacement for Alchemy / Infura / QuickNode with hedged requests, automatic failover across node vendors, flashblocks, and pay-per-request (x402). Reach for Edge whenever you need a reliable RPC endpoint, not just indexing.

| Skill | When to use | What's inside |
| ----- | ----------- | ------------- |
| `edge` | "RPC rate limits, hedged requests, flashblocks, x402, error code -32005" | Capabilities, supported chains, pricing, dashboard, error code reference |

### Cross-cutting

Used across multiple products.

| Skill | When to use | What it does |
| ----- | ----------- | ------------ |
| `auth-setup` | "Install the CLI / log in / switch projects / fix unauthorized errors" | Walks through CLI installation, login, and project switching |
| `secrets` | "Create credentials for PostgreSQL / ClickHouse / Kafka / webhook sinks" | Guides credential creation and secret management |
| `datasets` | "What's the dataset name for Polygon NFTs? What prefix does Solana use?" | Chain prefixes, dataset types, naming conventions |

## Pre-Deploy Hooks

The plugin runs hooks automatically on `goldsky turbo apply` commands:

| Hook | What it does |
| ---- | ------------ |
| `pre-deploy-validate` | Runs `goldsky turbo validate`, blocks on failure |
| `secret-check` | Verifies all `secret_name` references exist |
| `post-deploy-inspect` | Suggests `goldsky turbo inspect` after deploy |

## Coverage

The skills cover the full Goldsky product surface:

- **Turbo pipelines** — 130+ chain sources (EVM, Solana, Bitcoin, Stellar, Sui, NEAR, Starknet); SQL / TypeScript / dynamic table transforms; PostgreSQL, ClickHouse, Kafka, S3, Webhook, S2, SQS, MySQL, Pub/Sub sinks; streaming and job modes; full lifecycle and monitoring
- **Mirror pipelines** — Subgraph and direct-indexing sources, sinks, lifecycle, plus interactive diagnosis (legacy — prefer Turbo for new pipelines unless you need a subgraph entity source)
- **Subgraphs** — Author/build/deploy (`subgraph-builder`: schema design, AssemblyScript mappings, manifest, instant subgraphs, performance, testing, endpoints/tags/webhooks); interactive diagnosis (`subgraph-doctor`); guided migration from The Graph (`subgraph-migrate`)
- **Compose** — `compose.yaml` manifest, cron / HTTP / onchain triggers, smart wallets, gas sponsorship, `TaskContext` API, codegen, pricing
- **Edge RPC** — Capabilities, supported chains, hedged requests, flashblocks, x402, error code lookups
- **Cross-cutting** — Authentication, secrets, dataset naming, full CLI reference

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
