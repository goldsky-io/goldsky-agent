# Goldsky Agent

AI-powered tools for streaming real-time blockchain data. Build, deploy, and debug Turbo pipelines that index onchain events from 130+ chains into PostgreSQL, ClickHouse, Kafka, and more.

## Quick Start

| I want to...                          | Use                  |
| ------------------------------------- | -------------------- |
| Build a new pipeline                  | `@pipeline-builder`  |
| Fix a broken pipeline                 | `@pipeline-doctor`   |
| Find the right dataset name           | `@dataset-finder`    |
| Look up YAML syntax                   | `turbo-pipelines`    |
| Check error patterns                  | `turbo-monitor-debug`|

Just describe what you need in natural language — the right agent or skill is selected automatically.

## Installation

**Claude Code**

```
/plugin marketplace add goldsky-io/goldsky-agent
/plugin install goldsky@goldsky-agent
```

**Cursor**

Clone the repo and add it as a local plugin:

```bash
git clone https://github.com/goldsky-io/goldsky-agent.git
```

Then add the path to your Cursor settings (`Settings > Cursor Settings > JSON`):

```json
{
  "plugins.local": ["/absolute/path/to/goldsky-agent"]
}
```

<details>
<summary>Other installation methods</summary>

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
├── agents/              # Interactive workflows (call with @agent-name)
│   ├── pipeline-builder.md    # Step-by-step pipeline creation wizard
│   ├── pipeline-doctor.md     # Diagnose and fix pipeline issues
│   └── dataset-finder.md      # Quick dataset lookups
├── skills/              # Reference documentation (auto-loaded by agents)
│   ├── turbo-pipelines/       # YAML configuration reference
│   ├── turbo-transforms/      # SQL, TypeScript, dynamic tables
│   ├── turbo-monitor-debug/   # Error patterns, CLI commands
│   ├── turbo-lifecycle/       # List, pause, resume, delete
│   ├── turbo-architecture/    # Design patterns, sink selection
│   ├── datasets/              # Chain prefixes, dataset types
│   ├── secrets/               # Credential management
│   └── auth-setup/            # CLI installation, login
├── hooks/               # Pre/post deploy automation
│   └── scripts/               # Validation, secret checking
└── .claude-plugin/      # Plugin manifest
```

## How It Works

**Agents** are interactive workflows that walk you through multi-step tasks. Call them with `@agent-name` or just describe what you need.

**Skills** are reference documentation that agents read to answer your questions. They contain YAML syntax, error patterns, CLI commands, and troubleshooting guides.

```
User: "Build me a pipeline for USDC transfers on Base"
  ↓
@pipeline-builder (agent)
  ↓ reads
turbo-pipelines + datasets + secrets (skills)
  ↓
Generated pipeline.yaml + deployment
```

## Agents

| Agent | What it does | Example |
| ----- | ------------ | ------- |
| `@pipeline-builder` | Interactive wizard: chain → dataset → transforms → sink → deploy | "Index all Jupiter swaps on Solana into Postgres" |
| `@pipeline-doctor` | Systematic diagnosis: auth → status → logs → error patterns → fix | "My pipeline is stuck in error state" |
| `@dataset-finder` | Quick lookup returning dataset name + YAML snippet | "What dataset for Polygon NFTs?" |

## Skills (Reference)

| Skill | Contents |
| ----- | -------- |
| `turbo-pipelines` | YAML configuration reference — sources, transforms, sinks, troubleshooting |
| `turbo-transforms` | SQL (DataFusion), TypeScript/WASM, dynamic tables, HTTP handlers |
| `turbo-monitor-debug` | Error patterns, log analysis, TUI shortcuts, debugging guides |
| `turbo-lifecycle` | List, pause, resume, restart, delete — streaming vs job mode rules |
| `turbo-architecture` | Design patterns, streaming vs job mode, sink selection |
| `datasets` | Chain prefixes, dataset types, naming conventions |
| `secrets` | Credential formats for each sink type |
| `auth-setup` | CLI installation and login flow |

## Pre-Deploy Hooks

The plugin runs hooks automatically on `goldsky turbo apply` commands:

| Hook | What it does |
| ---- | ------------ |
| `pre-deploy-validate` | Runs `goldsky turbo validate`, blocks on failure |
| `secret-check` | Verifies all `secret_name` references exist |
| `post-deploy-inspect` | Suggests `goldsky turbo inspect` after deploy |

## Coverage

These tools cover the full Turbo pipeline surface:

- **Sources** — 130+ chains (EVM, Solana, Bitcoin, Stellar, Sui, NEAR, Starknet), source filtering, bounded ranges
- **Transforms** — SQL, TypeScript/WASM, dynamic tables, HTTP handlers
- **Sinks** — PostgreSQL, ClickHouse, Kafka, S3, Webhook, S2
- **Modes** — Streaming (continuous) and Job (batch with `end_block`)
- **Lifecycle** — Deploy, pause, resume, restart, delete
- **Monitoring** — Live inspect TUI, log analysis, error matching

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
