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
End-to-end worked examples — each carries the full app source and walks build → deploy → smoke test, off the shelf or customized. For a custom app that isn't one of these, use **compose**.
- **compose-bitcoin-oracle** - Cron task writing BTC/USD from CoinGecko to an onchain `PriceOracle` contract
- **compose-vrf** - Fetches verifiable randomness from drand and fulfills onchain `RandomnessRequested` events
- **compose-dividend-distribution** - Pays token holders pro-rata for a corporate action; Compose orchestrates a Turbo job-mode pipeline to snapshot holders, then pays each onchain
- **compose-compliance-oracle** - Compliance-gated payments: escrow contract + compliance screening (Webacy/mock/BYO) + oracle approve/reject callback; single-payee or P2P; any EVM chain; plus a reconcile cron

### Edge (managed RPC)
- **edge** - Managed RPC endpoints, capabilities, supported chains, error code lookups

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

**"Build me a pipeline for USDC transfers on Base"**
→ Uses: turbo-builder, turbo-pipelines, datasets, secrets

**"My pipeline is stuck in error state"**
→ Uses: turbo-doctor, turbo-operations

**"My Compose app is crashlooping"**
→ Uses: compose-doctor, compose-reference

**"Sync my subgraph entities into PostgreSQL"**
→ Uses: mirror, secrets

**"Build me a subgraph for an ERC-721 contract"**
→ Uses: subgraph-builder

**"My subgraph stopped syncing / won't deploy"**
→ Uses: subgraph-doctor, subgraph-builder

**"Migrate my subgraph from The Graph to Goldsky"**
→ Uses: subgraph-migrate, subgraph-builder

**"Build a compliance-gated payment system" / "wallet screening oracle" / "AML-gated transfers"**
→ Uses: compose-compliance-oracle, compose-reference

**"Build a price oracle that writes onchain"**
→ Uses: compose-bitcoin-oracle, compose-reference

**"Build a custom Compose app that isn't the example"**
→ Uses: compose, compose-reference

**"I need a fast, reliable RPC endpoint with hedged requests"**
→ Uses: edge

**"What dataset for Polygon NFTs?"**
→ Uses: datasets

## Documentation

- [Goldsky Docs](https://docs.goldsky.com)
- [AI Skills page](https://docs.goldsky.com/ai-skills)
- [GitHub Repository](https://github.com/goldsky-io/goldsky-agent)
- [Installation Guide](https://github.com/goldsky-io/goldsky-agent#installation)
