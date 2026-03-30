---
name: turbo-pipelines
description: "Turbo pipeline YAML reference and architecture guide. Covers: YAML field syntax (start_at, from, version, primary_key), source/transform/sink configuration, validation errors, resource sizing (xs–xxl), architecture decisions (dataset vs kafka, streaming vs job, fan-out vs fan-in, sink selection, pipeline splitting). Triggers on: 'what does field X do', 'what fields does a postgres sink need', 'what resource size', 'should I use kafka or dataset', 'how to structure my pipeline'. For writing transforms, use /turbo-transforms. For end-to-end building, use /turbo-builder."
---

# Turbo Pipeline Configuration & Architecture

YAML configuration reference and architecture guide for Turbo pipelines. For interactive pipeline building, use `/turbo-builder`. For troubleshooting, use `/turbo-doctor`. For transform implementation, use `/turbo-transforms`.

> **CRITICAL:** Always validate YAML with `goldsky turbo validate <file.yaml>` before showing complete pipeline YAML to the user or deploying.

---

## Quick Start

```yaml
name: my-first-pipeline
resource_size: s
sources:
  transfers:
    type: dataset
    dataset_name: base.erc20_transfers
    version: 1.2.0
    start_at: latest
transforms: {}
sinks:
  output:
    type: blackhole
    from: transfers
```

```bash
goldsky turbo validate pipeline.yaml   # Validate first
goldsky turbo apply pipeline.yaml -i   # Deploy + inspect
```

## Prerequisites

- **Goldsky CLI** — `curl https://goldsky.com | sh`
- **Turbo extension** (separate binary) — `curl https://install-turbo.goldsky.com | sh`
- **Logged in** — `goldsky login`
- Secrets created for sinks if using PostgreSQL, ClickHouse, Kafka, etc. (see `/secrets`)

---

## Architecture Decisions

### Source Type Selection

| Scenario                          | Source Type | Why                                          |
| --------------------------------- | ----------- | -------------------------------------------- |
| Decode contract events from logs  | `dataset`   | Need `raw_logs` + `_gs_log_decode()`         |
| Track token transfers             | `dataset`   | `erc20_transfers` has structured data        |
| Historical backfill + live        | `dataset`   | `start_at: earliest` processes history       |
| Live token balances               | `kafka`     | `latest_balances_v2` is a streaming topic    |
| Real-time state snapshots         | `kafka`     | Kafka delivers latest state continuously     |
| Only need new data going forward  | Either      | Dataset with `start_at: latest` or Kafka     |

> **Note:** Kafka sources are used in production but are not documented in official Goldsky docs. Contact Goldsky support for topic names.

### Data Flow Patterns

| Pattern              | When to Use                                          | Template                           |
| -------------------- | ---------------------------------------------------- | ---------------------------------- |
| **Linear**           | Single source, single destination, simple processing | `templates/linear-pipeline.yaml`   |
| **Fan-out**          | One source → multiple sinks (different views/subsets)| `templates/fan-out-pipeline.yaml`  |
| **Fan-in**           | Multiple event types → UNION ALL → one table         | `templates/fan-in-pipeline.yaml`   |
| **Multi-chain**      | Same logic across chains (separate pipelines)        | `templates/multi-chain-templated.yaml` |

For detailed pattern diagrams, YAML examples, and multi-chain deployment guidance, read `references/architecture-patterns.md`.

### Resource Sizing

| Size  | Workers | CPU   | Memory  | When to Use                                                      |
| ----- | ------- | ----- | ------- | ---------------------------------------------------------------- |
| `xs`  | —       | 0.4   | 0.5 Gi  | Small datasets, light testing                                    |
| `s`   | 1       | 0.8   | 1.0 Gi  | Simple filters, single source/sink, low volume (default)         |
| `m`   | 4       | 1.6   | 2.0 Gi  | Multiple sinks, Kafka streaming, moderate transform complexity   |
| `l`   | 10      | 3.2   | 4.0 Gi  | Multi-event decoding + UNION ALL, high-volume backfill           |
| `xl`  | 20      | 6.4   | 8.0 Gi  | Large chain backfills, complex JOINs                             |
| `xxl` | 40      | 12.8  | 16.0 Gi | Highest throughput; up to 6.3M rows/min                          |

Start small and scale up — defensive sizing avoids wasted resources.

### Sink Selection

| Destination          | Sink Type            | Best For                                      |
| -------------------- | -------------------- | --------------------------------------------- |
| Application DB       | `postgres`           | Row-level lookups, joins, application serving |
| Real-time aggregates | `postgres_aggregate` | Balances, counters, running totals via triggers|
| Analytics queries    | `clickhouse`         | Large-scale aggregations, time-series data    |
| Event processing     | `kafka`              | Downstream consumers, event-driven systems    |
| Serverless streaming | `s2_sink`            | S2.dev streams, alternative to Kafka          |
| Notifications        | `webhook`            | Lambda functions, API callbacks, alerts        |
| Data lake            | `s3_sink`            | Long-term archival, batch processing          |
| Testing              | `blackhole`          | Validate pipeline without writing data        |

For full sink field specifications, read `references/sink-reference.md`.

### Streaming vs Job Mode

| Scenario                             | Mode        | Why                                            |
| ------------------------------------ | ----------- | ---------------------------------------------- |
| Real-time dashboard                  | Streaming   | Continuous updates needed                      |
| Backfill 6 months of history         | Job         | One-time, stops when done                      |
| Real-time + catch-up on deploy       | Streaming   | `start_at: earliest` does backfill then streams|
| Export data to S3 once               | Job         | No need for continuous processing              |
| Webhook notifications on events      | Streaming   | Needs to react as events happen                |
| Load test with historical data       | Job         | Process and inspect, then discard              |

**Job mode rules:** Runs to completion, auto-deletes ~1hr after finishing. Must delete before redeploying. Cannot pause/resume/restart.

### Pipeline Splitting

**One pipeline when:** Shared source, shared intermediate transforms, atomic deployment.
**Multiple pipelines when:** Different sources, different lifecycle needs, different resource sizes, different chains.

---

## Configuration Reference

### Pipeline Structure

```yaml
name: my-pipeline          # Required: unique identifier (lowercase, hyphens)
resource_size: s            # Required: xs/s/m/l/xl/xxl
job: true                   # Optional: one-time batch (default: false = streaming)

sources:
  source_name:
    type: dataset           # or: kafka
    # ... source config

transforms:                 # Optional
  transform_name:
    type: sql               # or: script, handler, dynamic_table
    # ... transform config

sinks:
  sink_name:
    type: postgres           # or: clickhouse, kafka, webhook, s3_sink, etc.
    # ... sink config
```

### Source Configuration

#### Dataset Source

```yaml
sources:
  my_source:
    type: dataset
    dataset_name: <chain>.<dataset_type>
    version: <version>
    start_at: latest | earliest    # EVM chains
    # start_block: <slot_number>   # Solana only
    # end_block: <block_number>    # Optional: for bounded backfills
    # filter: >-                   # Optional: SQL WHERE for source-level pre-filtering
    #   address = '0x...' AND block_number >= 10000000
```

| Field          | Required | Description                                              |
| -------------- | -------- | -------------------------------------------------------- |
| `type`         | Yes      | `dataset` for blockchain data                            |
| `dataset_name` | Yes      | Format: `<chain>.<dataset_type>`                         |
| `version`      | Yes      | Dataset version (e.g., `1.2.0`)                          |
| `start_at`     | EVM      | `latest` or `earliest`                                   |
| `start_block`  | Solana   | Specific slot number (omit for latest)                   |
| `end_block`    | No       | Stop at this block (for bounded backfills)               |
| `filter`       | No       | SQL WHERE clause — pre-filters at ingestion (efficient)  |

Use `filter` for contract addresses and block ranges (coarse pre-filtering). Use transform `WHERE` for fine-grained filtering.

For chain prefixes and dataset types, see `/datasets`.

#### Kafka Source

```yaml
sources:
  my_source:
    type: kafka
    topic: base.raw.latest_balances_v2
```

No `start_at` or `version` fields. Optional: `filter`, `include_metadata`, `starting_offsets`.

### Transform Configuration

| Type            | Use Case                              |
| --------------- | ------------------------------------- |
| `sql`           | Filtering, projections, SQL functions |
| `script`        | Custom TypeScript/WASM logic          |
| `handler`       | Call external HTTP APIs to enrich     |
| `dynamic_table` | Lookup tables backed by a database    |

#### SQL Transform

```yaml
transforms:
  filtered:
    type: sql
    primary_key: id
    sql: |
      SELECT id, sender, recipient, amount
      FROM source_name
      WHERE amount > 1000
```

| Field         | Required | Description                            |
| ------------- | -------- | -------------------------------------- |
| `type`        | Yes      | `sql`                                  |
| `primary_key` | Yes      | Column for uniqueness/ordering         |
| `sql`         | Yes      | SQL query (reference sources by name)  |
| `from`        | No       | Override default source (for chaining) |

#### Transform Chaining

Chain transforms using `from`:

```yaml
transforms:
  step1:
    type: sql
    primary_key: id
    sql: SELECT * FROM source WHERE amount > 100
  step2:
    type: sql
    primary_key: id
    from: step1
    sql: SELECT *, 'processed' as status FROM step1
```

For TypeScript, handler, and dynamic table transforms, see `/turbo-transforms`.

### Sink Configuration

Quick examples for common sinks. For full field specs of all sink types, read `references/sink-reference.md`.

#### PostgreSQL

```yaml
sinks:
  output:
    type: postgres
    from: my_transform
    schema: public
    table: my_table
    secret_name: MY_POSTGRES_SECRET
    primary_key: id
```

#### ClickHouse

```yaml
sinks:
  output:
    type: clickhouse
    from: my_transform
    table: my_table
    secret_name: MY_CLICKHOUSE_SECRET
    primary_key: id
```

#### Blackhole (Testing)

```yaml
sinks:
  output:
    type: blackhole
    from: my_transform
```

---

## Checkpoint Behavior

- **Preserved by default** when updating a pipeline
- **Tied to source names** — renaming a source resets its checkpoint
- **Tied to pipeline names** — renaming the pipeline resets all checkpoints

To reset checkpoints: rename the source or pipeline. Warning: this reprocesses all historical data.

---

## Starter Templates

| Template                       | Description                       | Use Case                     |
| ------------------------------ | --------------------------------- | ---------------------------- |
| `minimal-erc20-blackhole.yaml` | Simplest pipeline, no credentials | Quick testing                |
| `filtered-transfers-sql.yaml`  | Filter by contract address        | USDC, specific tokens        |
| `postgres-output.yaml`         | Write to PostgreSQL               | Production data storage      |
| `multi-chain-pipeline.yaml`    | Combine multiple chains           | Cross-chain analytics        |
| `solana-transfers.yaml`        | Solana SPL tokens                 | Non-EVM chains               |
| `multi-sink-pipeline.yaml`     | Multiple outputs                  | Archive + alerts + streaming |
| `linear-pipeline.yaml`         | Simple decode → filter → sink     | Basic linear flow            |
| `fan-out-pipeline.yaml`        | One source → multiple sinks       | Multi-destination            |
| `fan-in-pipeline.yaml`         | Multiple events → UNION ALL       | Activity feeds               |
| `multi-chain-templated.yaml`   | Per-chain pipeline pattern        | Independent chain deploys    |

**Template location:** `templates/` (relative to this skill's directory)

---

## CLI Quick Reference

| Action                  | Command                                                |
| ----------------------- | ------------------------------------------------------ |
| Install Goldsky CLI     | `curl https://goldsky.com \| sh`                       |
| Install Turbo extension | `curl https://install-turbo.goldsky.com \| sh`         |
| **Validate (REQUIRED)** | `goldsky turbo validate pipeline.yaml`                 |
| Deploy/Update           | `goldsky turbo apply pipeline.yaml`                    |
| Deploy + Inspect        | `goldsky turbo apply pipeline.yaml -i`                 |
| List pipelines          | `goldsky turbo list`                                   |
| List datasets           | `goldsky dataset list` (slow, 30-60s)                  |
| List secrets            | `goldsky secret list`                                  |

For lifecycle commands (pause/resume/restart/delete) and monitoring (inspect/logs), see `/turbo-operations`.

---

## Troubleshooting

See `references/troubleshooting.md` for CLI hanging, validation errors, and runtime errors.

---

## Related

- **`/turbo-builder`** — Interactive wizard to build pipelines step-by-step
- **`/turbo-doctor`** — Diagnose and fix pipeline issues
- **`/turbo-operations`** — Lifecycle commands and monitoring reference
- **`/turbo-transforms`** — SQL, TypeScript, and dynamic table transform reference
- **`/datasets`** — Dataset names and chain prefixes
- **`/secrets`** — Sink credential management
