# Goldsky Agent Skills

AI-powered tools for building, deploying, and debugging Goldsky products — Turbo pipelines and Subgraphs — streaming real-time blockchain data from 130+ chains.

## Available Skills

### Pipeline Building
- **turbo-builder** - Interactive wizard for creating pipelines step-by-step
- **turbo-pipelines** - YAML configuration reference (sources, transforms, sinks)
- **turbo-transforms** - SQL, TypeScript, and dynamic table transforms
- **turbo-architecture** - Design patterns and architecture guidance

### Pipeline Operations
- **turbo-lifecycle** - Pause, resume, restart, delete commands
- **turbo-monitor-debug** - Error patterns, log analysis, debugging
- **turbo-doctor** - Interactive troubleshooting workflows

### Subgraph Deployment
- **subgraph-builder** - Interactive wizard for deploying subgraphs (no-code, low-code, source code)
- **subgraph-config** - Instant subgraph JSON config, subgraph.yaml, CLI flags reference
- **subgraph-migrate** - Migrate subgraphs from TheGraph, Alchemy, or other hosts
- **subgraph-architecture** - Design decisions: subgraph vs pipeline, cross-chain strategies, performance optimization

### Subgraph Operations
- **subgraph-lifecycle** - Pause, start, delete, tags, webhooks, endpoint management
- **subgraph-monitor-debug** - Error patterns, log analysis, stalled detection
- **subgraph-doctor** - Interactive troubleshooting workflows

### Data & Configuration
- **datasets** - Chain prefixes, dataset types, 130+ chains
- **secrets** - Credential management for sinks (PostgreSQL, ClickHouse, Kafka)
- **auth-setup** - CLI installation and authentication

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
→ Uses: turbo-doctor, turbo-monitor-debug

**"What dataset for Polygon NFTs?"**
→ Uses: datasets

**"Create a subgraph for my NFT contract on Ethereum"**
→ Uses: subgraph-builder, subgraph-config

**"Migrate my subgraph from TheGraph to Goldsky"**
→ Uses: subgraph-migrate, subgraph-lifecycle

**"My subgraph stopped syncing"**
→ Uses: subgraph-doctor, subgraph-monitor-debug

## Documentation

- [Goldsky Docs](https://docs.goldsky.com)
- [GitHub Repository](https://github.com/goldsky-io/goldsky-agent)
- [Installation Guide](https://github.com/goldsky-io/goldsky-agent#installation)
