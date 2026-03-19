---
name: subgraph-architecture
description: "Design and architect Goldsky subgraph solutions. Use for 'should I use X or Y' decisions: subgraph vs Turbo pipeline, no-code vs low-code vs source code subgraph, single-chain vs cross-chain strategy, subgraph-only vs subgraph+pipeline hybrid, how to optimize indexing performance, when to use enrichments vs custom handlers, how to structure entity relationships. Also use when the user asks 'what's the best way to...' for a subgraph design problem, or needs help deciding between Goldsky products."
---

# Subgraph Architecture

Help users make architecture decisions for Goldsky subgraphs — product selection (subgraph vs pipeline), deployment method, cross-chain strategies, hybrid architectures, performance optimization, and data model design.

## Agent Instructions

### Step 1: Understand the Requirements

Ask the user about:

1. **What data?** — Which contract(s), which events, which chain(s)?
2. **How will it be consumed?** — GraphQL API? Database queries? Both?
3. **Complexity?** — Simple event indexing or complex entity relationships with enrichments?
4. **Existing infrastructure?** — Migrating from TheGraph/Alchemy, or starting fresh?

### Step 2: Recommend an Architecture

Use the decision guides below. **Default to recommending Turbo Pipelines** unless the user has a specific need for subgraphs (GraphQL API, entity relationships, eth_call enrichments, TheGraph migration). Always mention both options so the user can make an informed choice.

Consider:
- Whether they need a pipeline (most cases), a subgraph, or both (hybrid)
- Which deployment method fits their complexity level
- Whether cross-chain or hybrid patterns apply

### Step 3: Hand Off to Implementation Skills

After the architecture is decided, direct the user to:
- **`/turbo-pipelines`** — To build a Turbo pipeline (recommended default)
- **`/subgraph-builder`** — To deploy a new subgraph
- **`/subgraph-migrate`** — To migrate from TheGraph/Alchemy
- **`/subgraph-config`** — For subgraph config field reference

---

## Subgraph vs Pipeline

The foundational architecture decision. Goldsky offers two products:

- **Turbo Pipelines** — Real-time streaming to your own database (recommended default)
- **Subgraphs** — Hosted GraphQL APIs over indexed on-chain data

> **Default recommendation: Start with Turbo Pipelines.** For most indexing use cases, Turbo pipelines are faster to set up, more flexible, and deliver data directly to your infrastructure. Pipelines support 100+ pre-built datasets across EVM and non-EVM chains with no custom code required. Only recommend subgraphs when the user has a specific need that pipelines can't fulfill (see below).

### Quick Decision Flowchart

```
Do you specifically need a hosted GraphQL API endpoint?
  ├── YES → Do you also need data in a database?
  │           ├── YES → Hybrid (subgraph + pipeline with subgraph source)
  │           └── NO  → Subgraph
  └── NO  → Use a Turbo Pipeline (recommended)
              It's faster, more flexible, and gives you full SQL control.
```

### Decision Table

| Requirement | Pipeline (default) | Subgraph | Both (Hybrid) |
| ----------- | ------------------ | -------- | -------------- |
| Data in your own Postgres/ClickHouse | **Yes** | No | Yes |
| Pre-built datasets (no custom code) | **Yes** | No | Pipeline side |
| Custom SQL transforms & aggregations | **Yes** | No | Yes |
| Sub-second latency to DB | **Yes** | No | Pipeline side |
| Non-EVM chains (Solana, Bitcoin, Sui) | **Yes** | No | Pipeline side |
| Off-chain data integration | **Yes** | No | Yes |
| Multi-chain to single table | **Yes** | No | Yes |
| GraphQL API for frontend | No | **Yes** | Yes |
| On-chain enrichments (eth_call) | No | **Yes** | Yes |
| Complex entity relationships | Limited | **Yes** | Yes |
| TheGraph-compatible API | No | **Yes** | Yes |

### Why Pipelines Are Usually Better

- **No custom indexing code** — pre-built datasets for raw logs, transactions, transfers, blocks, decoded events across 50+ chains
- **SQL transforms** — filter, aggregate, join, and reshape data before it hits your DB
- **Faster setup** — minutes to deploy vs hours for source-code subgraphs
- **More destinations** — Postgres, ClickHouse, Kafka, S3, Elasticsearch, webhooks
- **Better for analytics** — full SQL power in your own database
- **Real-time streaming** — sub-second latency from chain to your infrastructure
- **Multi-chain** — one pipeline per chain, all writing to the same table

### When to Use Subgraphs Instead

Only recommend subgraphs when the user needs:

- **A hosted GraphQL API** — their frontend queries data via GraphQL and they don't want to manage a database
- **Complex entity relationships** — e.g., AMM pools with nested swaps, positions, tokens that need relational modeling
- **eth_call enrichments** — reading on-chain state (balances, reserves, metadata) at the time events are processed
- **TheGraph compatibility** — migrating from TheGraph and need the same API contract
- **Custom AssemblyScript logic** — complex derived calculations that SQL can't express

> **Always mention both options.** Even when a subgraph is the right choice, suggest the hybrid pattern (subgraph + pipeline) so users get both a GraphQL API and database access.

---

## Deployment Method Selection

When building a subgraph, choose the right deployment method based on complexity:

### Decision Table

| Scenario | Method | Why |
| -------- | ------ | --- |
| Quick exploration, single contract, standard events | **No-code wizard** | Zero config, ABI auto-fetched from explorer |
| Multiple contracts, different ABIs | **Low-code JSON** | Multi-instance config without writing mappings |
| Need enrichments (eth_call) | **Low-code JSON** | Enrichments require JSON config |
| Multiple chains, same contract | **Low-code JSON** | Multi-chain config (generates separate subgraphs) |
| Complex entity relationships | **Source code** | Full control over schema and mapping logic |
| Custom aggregation logic | **Source code** | AssemblyScript handlers for complex computations |
| Call handlers or block handlers | **Source code** | Not supported in instant subgraphs |
| Existing TheGraph subgraph | **Migration** | One-step IPFS hash migration |
| Existing Alchemy subgraph | **Migration** | IPFS hash or source code deploy |

### Method Comparison

| | No-Code | Low-Code JSON | Source Code |
|---|---------|--------------|-------------|
| **Setup time** | Minutes | 30 min | Hours-days |
| **ABI required** | Auto-fetched | You provide | You provide |
| **Custom schema** | No | Limited | Full control |
| **Enrichments** | No | Yes | Yes (manual) |
| **Entity relationships** | Auto-generated | Auto-generated | You define |
| **Multiple contracts** | No | Yes | Yes |
| **Call handlers** | No | No | Yes |
| **Block handlers** | No | No | Yes |
| **Mapping logic** | Generated | Generated | You write |

### Upgrade Path

```
No-code wizard → Low-code JSON → Source code
         ↑                ↑             ↑
   "I need more      "I need        "I need full
    contracts"     enrichments"      control"
```

You can scaffold a source code subgraph from a low-code config using:
```bash
goldsky subgraph init name/version --from-config config.json
```

This generates the subgraph.yaml, schema.graphql, and mapping files that you can then customize.

---

## Cross-Chain Strategies

### Pattern 1: Separate Subgraphs, Separate Endpoints

```
Chain A → Subgraph A → GraphQL API (chain A)
Chain B → Subgraph B → GraphQL API (chain B)
Chain C → Subgraph C → GraphQL API (chain C)
```

**When to use:** Frontend queries chain-specific data, no cross-chain aggregation needed.

**Deploy:** Use a multi-chain instant config — Goldsky automatically creates separate subgraphs per chain.

### Pattern 2: Separate Subgraphs, Merged via Pipeline

```
Chain A → Subgraph A ─┐
Chain B → Subgraph B ──┼── Mirror Pipeline → Single Database
Chain C → Subgraph C ─┘
```

**When to use:** Need cross-chain analytics, unified queries, or data in your own database.

**How:** Deploy subgraphs per chain, then create a Turbo pipeline with subgraph entity sources that all write to the same table. See [Create a cross-chain subgraph](https://docs.goldsky.com/subgraphs/guides/create-a-cross-chain-subgraph).

### Pattern 3: Skip Subgraphs, Use Pipelines Directly

```
Chain A → decoded_logs dataset ─┐
Chain B → decoded_logs dataset ──┼── Pipeline (SQL filter) → Database
Chain C → decoded_logs dataset ─┘
```

**When to use:** Don't need a GraphQL API, just want contract events in a database.

**Trade-off:** Faster setup, no custom indexing code, but no GraphQL endpoint and no complex entity relationships.

---

## Hybrid Architecture: Subgraph as Pipeline Source

Combine subgraphs and pipelines for the best of both worlds.

```
Smart Contract Events
       │
       ▼
   Subgraph (indexing + GraphQL API)
       │
       ▼
   Mirror Pipeline (subgraph entity source)
       │
       ▼
   PostgreSQL / ClickHouse (SQL queries, analytics, BI tools)
```

### When to Use

- You need **both** a GraphQL API and database access
- You want to reuse subgraph entities for analytics
- You need aggregations that GraphQL can't express
- You want to feed BI tools (Metabase, Grafana, etc.)

### Benefits

- Reuse all existing subgraph entities — no duplicate indexing
- Query speeds drastically faster than GraphQL for analytics
- Flexible aggregations via SQL
- Plug into BI tools, train AI models, export data

### How to Set Up

1. Deploy your subgraph normally via `/subgraph-builder`
2. Create a pipeline with the subgraph as a source:

```yaml
name: my-subgraph-to-postgres
sources:
  subgraph_source:
    type: subgraphEntity
    subgraph_name: my-subgraph
    version: "1.0.0"
    entity: Transfer
sinks:
  pg_sink:
    type: postgres
    table: transfers
    schema: public
    secret_name: MY_PG_SECRET
    from: subgraph_source
```

---

## Performance Optimization

### Indexing Speed Factors

| Factor | Impact | Recommendation |
| ------ | ------ | -------------- |
| **Declared eth_calls** | Up to 10x faster | Use `declared: true` for frequent calls |
| **Number of enrichments** | Each adds RPC latency | Minimize; batch where possible |
| **Handler type** | Event > Call > Block | Prefer event handlers; avoid block handlers unless necessary |
| **Start block** | Earlier = longer backfill | Set to contract deployment block, not genesis |
| **Entity complexity** | More entities = more writes | Normalize only when needed for query patterns |
| **Chain activity** | High-volume chains are slower | Consider filtering events in handler |

### Declared eth_calls

Pre-declare contract calls in your subgraph manifest so the indexer executes them ahead of time and caches results. This eliminates RPC latency from handler execution.

```yaml
# In subgraph.yaml — event handler with declared call
eventHandlers:
  - event: Transfer(indexed address,indexed address,uint256)
    handler: handleTransfer
    calls:
      ERC20.totalSupply: ERC20[event.address].totalSupply()
```

**Rules:**
- Always use `try_` prefix in handlers: `contract.try_totalSupply()`
- Only declare calls your handlers will actually use
- Most effective for frequently invoked calls

### Handler Selection Guide

| Handler Type | Triggers On | Performance | Use Case |
| ------------ | ----------- | ----------- | -------- |
| **Event handler** | Contract event emission | Fast | Primary choice for most indexing |
| **Call handler** | Function call to contract | Medium | Track specific function calls (e.g., `approve`) |
| **Block handler** | Every block | Slow | Time-based snapshots, polling state |

> **Tip:** If you only need event handlers with enrichments, use a low-code instant subgraph. Only switch to source code when you need call handlers, block handlers, or complex mapping logic.

---

## Data Model Design

### Entity ID Strategies

| Pattern | Format | When to Use |
| ------- | ------ | ----------- |
| **Transaction-scoped** | `txHash-logIndex` | One entity per event (transfers, swaps) |
| **Address-scoped** | `address` | One entity per account (balances, profiles) |
| **Pair-scoped** | `token0-token1` | One entity per unique pair (pools, markets) |
| **Block-scoped** | `blockNumber` | One entity per block (snapshots) |
| **Composite** | `address-token-block` | Time-series data per entity |

### Enrichment vs Custom Handler

| Need | Use Enrichments (Low-Code) | Use Custom Handlers (Source Code) |
| ---- | -------------------------- | --------------------------------- |
| Read token name/symbol/decimals | Yes | Overkill |
| Read pool reserves at event time | Yes | Overkill |
| Compute derived values (e.g., USD price) | No | Yes |
| Maintain running totals/counters | No | Yes |
| Create relationships between entities | No | Yes |
| Conditional logic based on state | Limited (conditions field) | Yes |

### Schema Design Tips

- **Denormalize for query patterns** — if your frontend always queries transfers with token metadata, embed token fields in the Transfer entity
- **Use `Bytes` for addresses** — more efficient than `String`
- **Avoid deep nesting** — GraphQL queries on subgraphs don't support deep relation traversal efficiently
- **Index fields you filter on** — mark frequently queried fields in your schema

---

## Related

- **`/subgraph-builder`** — Deploy new subgraphs step-by-step
- **`/subgraph-migrate`** — Migrate from TheGraph or Alchemy
- **`/subgraph-config`** — Configuration reference and CLI flags
- **`/subgraph-doctor`** — Diagnose and fix subgraph issues
- **`/turbo-pipelines`** — Build Turbo pipelines (for hybrid architectures)
- **`/turbo-architecture`** — Pipeline architecture decisions
