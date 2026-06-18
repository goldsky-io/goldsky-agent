# Goldsky Agent Skills

AI-powered tools for building, deploying, and debugging across the full Goldsky product surface — Turbo pipelines, Mirror pipelines, Subgraphs, Compose, and Edge RPC.

## Available Skills

### Turbo pipelines
- **turbo-builder** - Interactive wizard for creating pipelines step-by-step
- **turbo-doctor** - Interactive troubleshooting workflows
- **turbo-pipelines** - YAML configuration and architecture reference (sources, transforms, sinks, design patterns)
- **turbo-transforms** - SQL, TypeScript, and dynamic table transforms
- **turbo-operations** - Lifecycle commands, monitoring, and error patterns

### Mirror pipelines
- **mirror** - Sources, sinks, lifecycle commands, and guidance on Mirror vs Turbo
- **mirror-doctor** - Diagnose and fix broken Mirror pipelines interactively

### Subgraphs
- **subgraphs** - Deploy subgraphs, manage GraphQL endpoints, tags, and webhooks
- **subgraph-doctor** - Diagnose and fix failing, stalled, or stuck subgraphs interactively
- **subgraph-migrate-thegraph** - Guided migration of a subgraph from The Graph

### Compose
- **compose** - Build offchain-to-onchain TypeScript tasks (oracles, keepers, automation)
- **compose-doctor** - Diagnose and fix broken Compose apps interactively
- **compose-reference** - `compose.yaml` fields, every `goldsky compose` flag, `TaskContext` / wallet / Collection APIs

### Edge (managed RPC)
- **edge** - Managed RPC endpoints, capabilities, supported chains, error code lookups

### Cross-cutting
- **datasets** - Chain prefixes, dataset types, 130+ chains
- **secrets** - Credential management for sinks (PostgreSQL, ClickHouse, Kafka, etc.)
- **auth-setup** - CLI installation and authentication
- **cli-reference** - All valid `goldsky` subcommands, arguments, and flags (auto-generated)

## Quick Start

```bash
# Install all skills
npx skills add goldsky-io/goldsky-agent

# The installer will prompt you to select your AI agent
# Or specify directly: npx skills add goldsky-io/goldsky-agent -a <agent-name>
```

## Examples

**"Build me a pipeline for USDC transfers on Base"**
→ Uses: turbo-builder, turbo-pipelines, datasets, secrets

**"My pipeline is stuck in error state"**
→ Uses: turbo-doctor, turbo-operations

**"My Compose app is crashlooping"**
→ Uses: compose-doctor, compose-reference

**"Sync my subgraph entities into PostgreSQL"**
→ Uses: mirror, secrets

**"My subgraph stopped syncing / won't deploy"**
→ Uses: subgraph-doctor, subgraphs

**"Migrate my subgraph from The Graph to Goldsky"**
→ Uses: subgraph-migrate-thegraph, subgraphs

**"What dataset for Polygon NFTs?"**
→ Uses: datasets

## Documentation

- [Goldsky Docs](https://docs.goldsky.com)
- [AI Skills page](https://docs.goldsky.com/ai-skills)
- [GitHub Repository](https://github.com/goldsky-io/goldsky-agent)
- [Installation Guide](https://github.com/goldsky-io/goldsky-agent#installation)
