---
name: turbo-architecture
description: Design and architect Turbo pipelines. Use when choosing between source types (dataset vs kafka), designing data flow patterns (fan-in, fan-out, linear), sizing resources, planning multi-chain deployments, or deciding how to split work across pipelines.
---

# Turbo Pipeline Architecture

Help users make architecture decisions for Turbo pipelines — source types, data flow patterns, resource sizing, sink strategies, and multi-chain deployment.

## Triggers

Invoke this skill when the user:

- Asks "how should I structure my pipeline" or "what's the best approach for..."
- Needs to choose between dataset and kafka source types
- Wants to send data to multiple destinations
- Is planning a multi-chain deployment
- Asks about resource sizing (s, m, l)
- Wants to split or combine pipelines
- Asks about `parallelism`, sink performance, or throughput
- Needs to decide between one big pipeline vs several smaller ones
- Mentions `/turbo-architecture`

## Agent Instructions

### Step 1: Understand the Requirements

Ask the user about:

1. **What data?** — Which chain(s), which events/datasets, historical or real-time only?
2. **Where does it go?** — Database, webhook, streaming topic, multiple destinations?
3. **How much volume?** — Single contract or all chain activity? How many events/sec?
4. **Latency needs?** — Real-time dashboards (sub-second) or analytics (minutes OK)?

### Step 2: Recommend an Architecture

Use the patterns and decision guides below to recommend a pipeline architecture. Reference the templates in `templates/` as starting points:

- `templates/linear-pipeline.yaml` — Simple decode → filter → sink
- `templates/fan-out-pipeline.yaml` — One source → multiple sinks
- `templates/fan-in-pipeline.yaml` — Multiple events → UNION ALL → sink
- `templates/multi-chain-templated.yaml` — Per-chain pipeline pattern

### Step 3: Hand Off to Implementation Skills

After the architecture is decided, direct the user to:
- **`/turbo-pipelines`** — To build and deploy the YAML
- **`/turbo-transforms`** — To write the SQL transforms
- **`/goldsky-secrets`** — To set up sink credentials

---

## Source Types

### Dataset Sources — Historical + Real-Time

Use `type: dataset` when you need to process historical blockchain data and/or continue streaming new data.

```yaml
sources:
  my_source:
    type: dataset
    dataset_name: base.erc20_transfers
    version: 1.2.0
    start_at: earliest  # or: latest
```

**Best for:** Raw logs, transactions, transfers, blocks — anything where you need historical backfill or decoded event processing.

**Available EVM datasets:** `raw_logs`, `blocks`, `raw_transactions`, `raw_traces`, `erc20_transfers`, `erc721_transfers`, `erc1155_transfers`, `decoded_logs`

**Non-EVM chains also supported:** Solana (`solana.*`), Bitcoin (`bitcoin.raw.*`), Stellar (`stellar_mainnet.*`)

### Kafka Sources — Real-Time Streaming

> **Note:** Kafka sources are used in production pipelines but are **not documented** in the official Goldsky docs. Use with caution and contact Goldsky support for topic names.

Use `type: kafka` when consuming from a Goldsky-managed Kafka topic, typically for continuously-updated state like balances.

```yaml
sources:
  my_source:
    type: kafka
    topic: base.raw.latest_balances_v2
```

**Best for:** Balance snapshots, latest state data, high-volume continuous streams.

**Key differences from dataset sources:**
- No `start_at` or `version` fields
- Optional fields: `filter`, `include_metadata`, `starting_offsets`
- Delivers the latest state rather than historical event logs

### When to Use Which

| Scenario                          | Source Type | Why                                          |
| --------------------------------- | ----------- | -------------------------------------------- |
| Decode contract events from logs  | `dataset`   | Need `raw_logs` + `_gs_log_decode()`         |
| Track token transfers             | `dataset`   | `erc20_transfers` has structured data        |
| Historical backfill + live        | `dataset`   | `start_at: earliest` processes history       |
| Live token balances               | `kafka`     | `latest_balances_v2` is a streaming topic    |
| Real-time state snapshots         | `kafka`     | Kafka delivers latest state continuously     |
| Only need new data going forward  | Either      | Dataset with `start_at: latest` or Kafka     |

---

## Data Flow Patterns

### Linear Pipeline

The simplest pattern. One source → one or more chained transforms → one sink.

```
source → transform_a → transform_b → sink
```

**Use when:** You have a single data source, single destination, and straightforward processing (decode, filter, reshape).

**Example:** `templates/linear-pipeline.yaml` — raw logs → decode → extract trade events → postgres

**Resource size:** `s` or `m`

### Fan-Out (One Source → Multiple Sinks)

One source feeds multiple transforms, each writing to a different sink.

```
              ┌→ transform_a → sink_1 (clickhouse)
source ──────┤
              └→ transform_b → sink_2 (webhook)
```

**Use when:** You need different views or subsets of the same data going to different destinations — e.g., balances to a warehouse AND token metadata to a webhook.

**Example:** `templates/fan-out-pipeline.yaml` — one Kafka source → fungible balances to ClickHouse + all tokens to a webhook

```yaml
transforms:
  fungible_balances:
    type: sql
    primary_key: id
    sql: |
      SELECT ... FROM latest_balances balance
      WHERE balance.token_type = 'ERC_20' OR balance.token_type IS NULL

  all_tokens:
    type: sql
    primary_key: id
    sql: |
      SELECT ... FROM latest_balances balance
      WHERE balance.token_type IN ('ERC_20', 'ERC_721', 'ERC_1155')

sinks:
  warehouse:
    type: clickhouse
    from: fungible_balances
    # ...
  webhook:
    type: webhook
    from: all_tokens
    # ...
```

**Resource size:** `m` (multiple output paths)

### Fan-In (Multiple Events → One Output)

Multiple event types decoded from the same source, normalized to a common schema, then combined with UNION ALL into a single sink.

```
              ┌→ event_type_a ──┐
source → decode ┤                 ├→ UNION ALL → sink
              └→ event_type_b ──┘
```

**Use when:** You want a unified activity feed, combining trades, deposits, withdrawals, transfers, etc. into one table.

**Example:** `templates/fan-in-pipeline.yaml` — one raw_logs source → decode → multiple event-type transforms → UNION ALL → ClickHouse

**Resource size:** `l` (complex processing with many transforms)

### Multi-Chain Fan-In

Multiple sources from different chains combined into a single output.

```
source_chain_a ──┐
source_chain_b ──┼→ UNION ALL → sink
source_chain_c ──┘
```

**Use when:** You want cross-chain analytics or a unified view across chains.

```yaml
sources:
  eth_transfers:
    type: dataset
    dataset_name: ethereum.erc20_transfers
    version: 1.0.0
    start_at: latest
  base_transfers:
    type: dataset
    dataset_name: base.erc20_transfers
    version: 1.2.0
    start_at: latest

transforms:
  combined:
    type: sql
    primary_key: id
    sql: |
      SELECT *, 'ethereum' AS chain FROM eth_transfers
      UNION ALL
      SELECT *, 'base' AS chain FROM base_transfers
```

**Resource size:** `m` or `l` depending on chain count

---

## Templated Multi-Chain Deployment

When you need the **same pipeline logic** across multiple chains, create separate pipeline files per chain rather than one multi-source pipeline. This gives you:

- Independent lifecycle (deploy/delete per chain)
- Independent checkpointing (one chain failing doesn't block others)
- Clearer monitoring per chain

**Pattern:** Copy the pipeline YAML and swap the chain-specific values:

| Field              | Chain A (base)                    | Chain B (arbitrum)                    |
| ------------------ | --------------------------------- | ------------------------------------- |
| `name`             | `base-balance-streaming`          | `arbitrum-balance-streaming`          |
| `topic`            | `base.raw.latest_balances_v2`     | `arbitrum.raw.latest_balances_v2`     |
| Source key         | `base_latest_balances_v2`         | `arbitrum_latest_balances_v2`         |
| Transform SQL      | `'base' AS chain`                 | `'arbitrum' AS chain`                 |
| Sink table         | `base_token_balances`             | `arbitrum_token_balances`             |

**Example:** `templates/multi-chain-templated.yaml` — shows the base chain version; duplicate for each chain.

**When to use templated vs multi-source:**

| Approach                | Pros                                          | Cons                                |
| ----------------------- | --------------------------------------------- | ----------------------------------- |
| Templated (per-chain)   | Independent lifecycle, clear monitoring        | More files to manage                |
| Multi-source (one file) | Single deployment, cross-chain UNION possible  | Coupled lifecycle, harder to debug  |

---

## Resource Sizing

| Size | Workers | When to Use                                                    |
| ---- | ------- | -------------------------------------------------------------- |
| `s`  | 1       | Testing, simple filters, single source/sink, low volume        |
| `m`  | 2       | Multiple sinks, Kafka streaming, moderate transform complexity |
| `l`  | 4       | Multi-event decoding with UNION ALL, high-volume historical backfill, complex processing |

**Rules of thumb from production pipelines:**

- Simple filter + single sink → `s`
- Kafka source + multiple sinks OR multiple transforms → `m`
- Raw log decoding + 5+ event types + UNION ALL → `l`
- Historical backfill of high-volume data → `l` (can downsize after catch-up)

---

## Sink Strategy

### Choosing a Sink Type

| Destination          | Sink Type            | Best For                                      |
| -------------------- | -------------------- | --------------------------------------------- |
| Analytics queries    | `clickhouse`         | Large-scale aggregations, time-series data    |
| Application DB       | `postgres`           | Row-level lookups, joins, application serving |
| Real-time aggregates | `postgres_aggregate` | Balances, counters, running totals via triggers|
| Event processing     | `kafka`              | Downstream consumers, event-driven systems    |
| Notifications        | `webhook`            | Lambda functions, API callbacks, alerts        |
| Data lake            | `s3_sink`            | Long-term archival, batch processing          |
| Serverless streaming | `s2_sink`            | S2.dev streams, alternative to Kafka          |
| Testing              | `blackhole`          | Validate pipeline without writing data        |

### Multi-Sink Considerations

- Each sink reads from a `from:` field — different sinks can read from different transforms
- Sinks are independent — one failing doesn't block others
- Use different `batch_size` / `batch_flush_interval` per sink based on latency needs

### Sink Parallelism

ClickHouse and other sinks support a `parallelism` setting:

```yaml
sinks:
  my_sink:
    type: clickhouse
    from: my_transform
    parallelism: 1   # number of concurrent writers
    # ...
```

Use `parallelism: 1` for most cases. Increase only if the sink can handle concurrent writes and you need higher throughput.

### Webhook Sinks Without Secrets

Webhooks can use a direct URL instead of a secret when no auth headers are needed:

```yaml
sinks:
  my_webhook:
    type: webhook
    from: my_transform
    url: https://my-lambda.us-west-2.on.aws/
```

---

## Pipeline Splitting Decisions

### One Pipeline vs. Multiple

**Use one pipeline when:**
- All data comes from the same source
- Transforms share intermediate results (e.g., a shared decode step)
- You want atomic deployment of the whole flow

**Split into multiple pipelines when:**
- Different data sources with no shared transforms
- Different lifecycle needs (one is stable, another changes frequently)
- Different resource requirements (one needs `l`, another needs `s`)
- Different chains with independent processing (templated pattern)

### Keeping Pipelines Focused

A pipeline should ideally do **one logical thing**:

| Pipeline                        | Focus                               |
| ------------------------------- | ----------------------------------- |
| `dex-trades`                    | Trade events → Postgres             |
| `dex-activities`                | All activity types → ClickHouse DWH |
| `token-balances`                | Token balances → Postgres           |
| `base-balance-streaming`        | Base balances → ClickHouse + webhook |

Even though trades are a subset of activities, they're separate pipelines because they serve different consumers (application DB vs data warehouse).

---

## Related Skills

- **`/turbo-pipelines`** — Build and deploy pipeline YAML configurations
- **`/turbo-transforms`** — Write SQL transforms (filtering, decoding, UNION ALL, etc.)
- **`/goldsky-datasets`** — Discover available blockchain datasets and chain prefixes
- **`/goldsky-secrets`** — Set up credentials for sinks
- **`/turbo-monitor-debug`** — Monitor pipeline health and debug issues
- **`/turbo-lifecycle`** — List, delete, and manage pipeline state
