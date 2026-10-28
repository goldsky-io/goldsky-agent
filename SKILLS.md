# Goldsky Agent Skills

AI-powered tools for building, deploying, and debugging Goldsky Turbo pipelines, Mirror pipelines, Subgraphs, Edge RPC, and Feeds. Compose skills, which send onchain transactions, are in [goldsky-io/goldsky-compose-agent](https://github.com/goldsky-io/goldsky-compose-agent).

## Available Skills

### Turbo pipelines
- **turbo-builder** - Interactive wizard for creating pipelines step-by-step
- **turbo-doctor** - Interactive troubleshooting workflows
- **turbo-pipelines** - YAML configuration and architecture reference (sources, transforms, sinks, design patterns)
- **turbo-transforms** - SQL, TypeScript, and dynamic table transforms
- **turbo-operations** - Lifecycle commands, monitoring, and error patterns

### Mirror pipelines
_Legacy streaming product — prefer Turbo for new pipelines unless you need a subgraph entity source._
- **mirror** - Sources, sinks, lifecycle commands, and guidance on Mirror vs Turbo
- **mirror-doctor** - Diagnose and fix broken Mirror pipelines interactively

### Subgraphs
- **subgraph-builder** - Author, build, and deploy subgraphs: schema design, AssemblyScript mappings, manifest, instant subgraphs, performance, testing, endpoints/tags/webhooks
- **subgraph-doctor** - Diagnose and fix failing, stalled, or stuck subgraphs interactively
- **subgraph-migrate** - Guided migration of a subgraph from The Graph

### RPC (Edge and Boost)
- **edge** - Managed RPC endpoints, capabilities, supported chains, error code lookups
- **boost** - Free CDN in front of an RPC provider you already pay for; cacheable reads served from Goldsky's data, everything else forwarded free

### Feeds
- **feeds** - One wallet's balances and transfers, metadata and current USD prices for up to 100 tokens per request, Polymarket activity, positions and balances, and block headers and chain head, over HTTP, with the key from `goldsky feeds key reveal` or x402 pay-per-request. Formerly Edge Data / Data APIs. The Feeds key is not the CLI login token

### Cross-cutting
- **datasets** - Chain prefixes, dataset types, 130+ chains
- **secrets** - Credential management for sinks (PostgreSQL, ClickHouse, Kafka, etc.)
- **auth-setup** - CLI installation and authentication

## Quick Start

```bash
# Install all skills
npx skills add goldsky-io/goldsky-agent

# The installer will prompt you to select your AI agent
# Or specify directly: npx skills add goldsky-io/goldsky-agent -a <agent-name>
```

## Examples

**"Install the Goldsky CLI, then run /get-started."**
→ Uses: `/get-started`, then auth-setup

**"Build me a pipeline for USDC transfers on Base"**
→ Uses: turbo-builder, turbo-pipelines, datasets, secrets

**"My pipeline is stuck in error state"**
→ Uses: turbo-doctor, turbo-operations

**"Sync my subgraph entities into PostgreSQL"**
→ Uses: mirror, secrets

**"Build me a subgraph for an ERC-721 contract"**
→ Uses: subgraph-builder

**"My subgraph stopped syncing / won't deploy"**
→ Uses: subgraph-doctor, subgraph-builder

**"Migrate my subgraph from The Graph to Goldsky"**
→ Uses: subgraph-migrate, subgraph-builder

**"I need a fast, reliable RPC endpoint with hedged requests"**
→ Uses: edge

**"What dataset for Polygon NFTs?"**
→ Uses: datasets

## Documentation

- [Goldsky Docs](https://docs.goldsky.com)
- [AI Skills page](https://docs.goldsky.com/ai-skills)
- [GitHub Repository](https://github.com/goldsky-io/goldsky-agent)
- [Installation Guide](https://github.com/goldsky-io/goldsky-agent#installation)
