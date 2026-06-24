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
_Legacy streaming product — prefer Turbo for new pipelines unless you need a subgraph entity source._
- **mirror** - Sources, sinks, lifecycle commands, and guidance on Mirror vs Turbo
- **mirror-doctor** - Diagnose and fix broken Mirror pipelines interactively

### Subgraphs
- **subgraph-builder** - Author, build, and deploy subgraphs: schema design, AssemblyScript mappings, manifest, instant subgraphs, performance, testing, endpoints/tags/webhooks
- **subgraph-doctor** - Diagnose and fix failing, stalled, or stuck subgraphs interactively
- **subgraph-migrate** - Guided migration of a subgraph from The Graph

### Compose
- **compose** - Build offchain-to-onchain TypeScript tasks (oracles, keepers, automation)
- **compose-doctor** - Diagnose and fix broken Compose apps interactively
- **compose-reference** - `compose.yaml` fields, every `goldsky compose` flag, `TaskContext` / wallet / Collection APIs

#### Compose examples
End-to-end worked examples — each scaffolds a real app from `goldsky-io/documentation-examples` and walks build → deploy → smoke test. For a custom app that isn't one of these, use **compose**.
- **compose-bitcoin-oracle** - Cron task writing BTC/USD from CoinGecko to an onchain `PriceOracle` contract
- **compose-vrf** - Onchain-event task fulfilling randomness requests with drand verifiable randomness
- **compose-copy-trader** - Turbo pipeline + Compose app that mirrors Polymarket trades from watched wallets
- **compose-dividend-distribution** - Pays a cap table pro-rata via a job-mode Turbo snapshot + gas-sponsored on-chain payouts; idempotent and crash-safe

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

**"Build me a subgraph for an ERC-721 contract"**
→ Uses: subgraph-builder, cli-reference

**"My subgraph stopped syncing / won't deploy"**
→ Uses: subgraph-doctor, subgraph-builder

**"Migrate my subgraph from The Graph to Goldsky"**
→ Uses: subgraph-migrate, subgraph-builder

**"Build a price oracle that writes onchain"**
→ Uses: compose-bitcoin-oracle, compose-reference

**"Build a custom Compose app that isn't one of the examples"**
→ Uses: compose, compose-reference

**"Build provably fair onchain randomness" / "mirror Polymarket trades" / "distribute dividends to a cap table"**
→ Uses: compose-vrf / compose-copy-trader / compose-dividend-distribution

**"I need a fast, reliable RPC endpoint with hedged requests"**
→ Uses: edge

**"What dataset for Polygon NFTs?"**
→ Uses: datasets

## Documentation

- [Goldsky Docs](https://docs.goldsky.com)
- [AI Skills page](https://docs.goldsky.com/ai-skills)
- [GitHub Repository](https://github.com/goldsky-io/goldsky-agent)
- [Installation Guide](https://github.com/goldsky-io/goldsky-agent#installation)
