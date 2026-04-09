---
name: mirror
description: "Use this skill when the user asks about Goldsky Mirror pipelines — creating, deploying, operating, or troubleshooting Mirror. Triggers on: 'Mirror pipeline', 'goldsky pipeline apply', 'sync subgraph to database', 'mirror vs turbo', 'direct indexing', 'mirror pipeline YAML', 'mirror pipeline pause/stop/restart'. Also use this skill when the user wants to sync a Goldsky subgraph into a database or message queue — Mirror is the only pipeline product that supports subgraph sources. For new pipelines that don't need a subgraph source, the turbo-builder skill is usually a better fit. Do NOT trigger on 'goldsky turbo' commands or generic 'build a pipeline' requests without subgraph context — those belong to the turbo skills."
---

# Goldsky Mirror Pipelines

Mirror is Goldsky's original streaming pipeline product. It reads onchain data from a **source** (a subgraph entity or a direct-indexing dataset), optionally applies **transforms**, and writes the result to a **sink** (your database or message queue).

### Mirror vs Turbo — which should you use?

| | Mirror | Turbo |
|---|---|---|
| Subgraph sources | **Yes** | No |
| Speed & reliability | Good | **Faster, more reliable** |
| Sink variety | 11 sink types | Growing — new sinks added regularly |
| Config complexity | Moderate | **Simpler YAML** |
| Dataset coverage | 130+ chains | 130+ chains, richer catalog |

**Use Turbo unless you need a subgraph source.** Turbo is faster, more reliable, and actively gaining feature parity with Mirror — especially sink support. If you don't have a subgraph requirement, say "help me build a Turbo pipeline" and the `/turbo-builder` skill will guide you through a faster setup.

---

## How Mirror Pipelines Work

```
Source (subgraph entity or direct-indexing dataset)
  ↓
Transforms (optional SQL or external handlers)
  ↓
Sink (PostgreSQL, ClickHouse, Kafka, S3, etc.)
```

A pipeline is defined in a YAML file (`apiVersion: 3`) and deployed with `goldsky pipeline apply`.

---

## Pipeline YAML Structure

Top-level fields:

| Field | Type | Required | Description |
| ----- | ---- | -------- | ----------- |
| `name` | string | yes | Lowercase letters, numbers, hyphens only. Under 50 characters. |
| `apiVersion` | number | yes | Always `3` |
| `resource_size` | string | no | `s` (default), `m`, `l`, `xl`, `xxl` |
| `description` | string | no | Pipeline description |
| `sources` | object | yes | At least one source |
| `transforms` | object | no | Use `{}` if none needed |
| `sinks` | object | yes | At least one sink |

---

## Sources

| Source type | YAML `type` value | Description |
| ----------- | ----------------- | ----------- |
| **Subgraph entity** | `subgraph_entity` | Mirror data from Goldsky-hosted subgraphs |
| **Dataset (direct indexing)** | `dataset` | Raw onchain datasets (blocks, logs, transactions, traces, transfers) |

### Subgraph entity source

```yaml
sources:
  subgraph_account:
    type: subgraph_entity
    name: account                # Entity name in your subgraph
    start_at: latest             # "earliest" or "latest" (default: latest)
    filter: ""                   # Optional SQL WHERE clause for fast scan
    subgraphs:
      - name: my-subgraph        # Deployed subgraph name
        version: 1.0.0
      - name: my-subgraph-arb    # Cross-chain: add more subgraphs
        version: 1.0.0
```

**Fields:** `type` (required: `subgraph_entity`), `name` (required: entity name), `subgraphs` (required: list of `{name, version}`), `start_at` (optional), `filter` (optional), `description` (optional).

### Dataset source

```yaml
sources:
  base_logs:
    type: dataset
    dataset_name: base.logs      # Use `goldsky dataset list` to discover names
    version: 1.0.0               # Use `goldsky dataset get <name>` for versions
    start_at: latest             # "earliest" or "latest" (default: latest)
    filter: "address = '0x...'"  # Optional — enables Fast Scan for backfills
```

**Fields:** `type` (required: `dataset`), `dataset_name` (required), `version` (required), `start_at` (optional), `filter` (optional), `description` (optional).

**Fast Scan:** When `filter` is defined on a dataset source with `start_at: earliest`, the filter is pre-applied at the source level, making historical backfill much faster. Use attributes that exist in the dataset schema (`goldsky dataset get <dataset_name>` to check).

See [docs.goldsky.com/mirror/sources/supported-sources](https://docs.goldsky.com/mirror/sources/supported-sources).

---

## Sinks

| Sink | YAML `type` value | Notes |
| ---- | ----------------- | ----- |
| **PostgreSQL** | `postgres` | Most common — OLTP, auto-creates tables, upsert via INSERT ON CONFLICT. Hosted option via NeonDB. |
| **ClickHouse** | `clickhouse` | OLAP — uses ReplacingMergeTree by default, `append_only_mode` for best performance |
| **MySQL** | `mysql` | OLTP workloads |
| **Elasticsearch** | `elasticsearch` | Real-time search and analytics |
| **Kafka** | `kafka` | High-throughput streaming to a topic, configurable `topic_partitions` |
| **Object Storage** | `file` | S3, GCS, or R2 — Parquet format, append-only, supports `partition_columns` |
| **AWS SQS** | `sqs` | Message queuing |
| **Webhook** | `webhook` | HTTP POST to an external endpoint |

All sinks writing to user-managed destinations require a **Goldsky Secret** (`secret_name`). Create one with `goldsky secret create`.

Sinks support `schema_override` for casting column types at the sink level (e.g., `string` to `jsonb`).

### Sink examples

```yaml
# PostgreSQL
sinks:
  my_pg:
    type: postgres
    table: transfers
    schema: public
    secret_name: MY_PG_SECRET
    from: my_transform

# ClickHouse
sinks:
  my_ch:
    type: clickhouse
    table: transfers
    database: my_db
    secret_name: MY_CH_SECRET
    from: my_source

# Kafka
sinks:
  my_kafka:
    type: kafka
    topic: accounts
    topic_partitions: 2
    secret_name: MY_KAFKA_SECRET
    from: my_source

# Object Storage (S3/GCS/R2)
sinks:
  my_s3:
    type: file
    path: s3://bucket/path/
    format: parquet
    secret_name: MY_S3_SECRET
    from: my_source

# SQS
sinks:
  my_sqs:
    type: sqs
    url: https://sqs.us-east-1.amazonaws.com/123456/my-queue
    secret_name: MY_SQS_SECRET
    from: my_source
```

See [docs.goldsky.com/mirror/sinks/supported-sinks](https://docs.goldsky.com/mirror/sinks/supported-sinks).

---

## Transforms

| Type | YAML `type` value | Description |
| ---- | ----------------- | ----------- |
| **SQL** | _(none — default)_ | Filter, join, or reshape records with SQL |
| **External handler** | `handler` | POST records to an HTTP endpoint for custom logic |

### SQL transform

```yaml
transforms:
  filtered_logs:
    sql: SELECT id, block_number, address FROM base_logs WHERE block_number > 1000
    primary_key: id
```

SQL transforms reference source or transform names as table names. Supports chaining (one transform reads from another).

**Built-in decode functions:**
- `_gs_log_decode(abi, topics, data)` — decode raw log events
- `_gs_tx_decode(abi, input, output)` — decode raw trace/transaction data
- `_gs_fetch_abi(url, type)` — fetch ABI from URL (etherscan-compatible or raw JSON); fetched once at pipeline start

### External handler transform

```yaml
transforms:
  my_handler:
    type: handler
    primary_key: id
    url: http://example.com/transform
    from: my_source
    batch_size: 100              # Records per batch (default: 100)
    batch_flush_interval: 1s     # Flush interval (default: 1s)
    payload_columns: [col1,col2] # Optional: send subset of columns
    headers:                     # Optional custom headers
      X-Api-Key: my-key
```

- At-least-once delivery with exponential backoff on failure
- Max response time: 5 minutes; max connection time: 1 minute
- Supports `schema_override` for return type casting

See [docs.goldsky.com/mirror/transforms/sql-transforms](https://docs.goldsky.com/mirror/transforms/sql-transforms).

---

## Full YAML Examples

### Subgraph entity to PostgreSQL

```yaml
name: my-subgraph-sync
apiVersion: 3
resource_size: s
sources:
  subgraph_transfer:
    type: subgraph_entity
    name: Transfer
    subgraphs:
      - name: uniswap-v3
        version: 1.0.0
transforms: {}
sinks:
  my_postgres:
    type: postgres
    table: transfers
    schema: public
    secret_name: MY_PG_SECRET
    from: subgraph_transfer
```

### Dataset (direct indexing) to PostgreSQL with SQL transform

```yaml
name: base-logs-filtered
apiVersion: 3
resource_size: s
sources:
  base_logs:
    type: dataset
    dataset_name: base.logs
    version: 1.0.0
    start_at: earliest
    filter: "address = '0x833589fcd6edb6e08f4c7c32d4f71b54bda02913'"
transforms:
  select_fields:
    sql: SELECT id, block_number, transaction_hash, data FROM base_logs
    primary_key: id
sinks:
  pg_logs:
    type: postgres
    table: base_logs
    schema: public
    secret_name: MY_PG_SECRET
    from: select_fields
```

> **No subgraph source?** You should almost certainly use Turbo instead — it's faster, more reliable, and has a richer dataset catalog with simpler syntax. Use `/turbo-builder` to get started.

---

## CLI Reference — All Pipeline Commands

Global options available on every command: `--token <string>` (CLI auth token), `--color` (colorize output, default true), `-h, --help`.

### `goldsky pipeline apply <config-path>`

Create or update a pipeline from a YAML config file. Idempotent.

| Flag | Type | Description |
| ---- | ---- | ----------- |
| `--status` | `ACTIVE \| INACTIVE \| PAUSED` | Desired pipeline status |
| `--from-snapshot` | string | Snapshot to start from: `last`, `new`, `none`, or a snapshot ID. `last` = latest available. `new` = create a fresh snapshot first. `none` = start from scratch. Default: `new` |
| `--force` | boolean | Skip confirmation prompts (useful for CI) |
| `--skip-transform-validation` | boolean | Skip transform validation on update |
| `--save-progress` | boolean | _(deprecated, use `--from-snapshot`)_ Attempt snapshot before applying |
| `--use-latest-snapshot` | boolean | _(deprecated, use `--from-snapshot`)_ Start from latest snapshot |
| `--skip-validation` | boolean | _(deprecated)_ Same as `--skip-transform-validation` |

```bash
goldsky pipeline apply my-pipeline.yaml --status ACTIVE
goldsky pipeline apply my-pipeline.yaml --status ACTIVE --from-snapshot last
goldsky pipeline apply my-pipeline.yaml --force   # CI/CD usage
```

### `goldsky pipeline start <nameOrConfigPath>`

Start a pipeline (equivalent to apply with `--status ACTIVE`).

| Flag | Type | Description |
| ---- | ---- | ----------- |
| `--from-snapshot` | string | `last`, `new`, `none`, or snapshot ID |
| `--use-latest-snapshot` | boolean | _(deprecated, use `--from-snapshot`)_ |

### `goldsky pipeline stop <nameOrConfigPath>`

Stop a pipeline **without** taking a snapshot. Sets status to INACTIVE, runtime to TERMINATED.

_No additional flags beyond global options._

### `goldsky pipeline pause <nameOrConfigPath>`

Pause a pipeline **with** a snapshot so it can resume from where it left off. Sets status to PAUSED, runtime to TERMINATED.

_No additional flags beyond global options._

### `goldsky pipeline restart <nameOrConfigPath>`

Restart a pipeline without configuration changes. Useful when the sink database was restarted, connection is stuck, etc.

| Flag | Type | Description |
| ---- | ---- | ----------- |
| `--from-snapshot` | string | **Required.** `last`, `new`, `none`, or snapshot ID |
| `--disable-monitoring` | boolean | Skip monitoring after restart (default: false) |

```bash
goldsky pipeline restart my-pipeline --from-snapshot last
goldsky pipeline restart my-pipeline --from-snapshot none  # restart from scratch
```

### `goldsky pipeline get <nameOrConfigPath>`

Get pipeline configuration and status.

| Flag | Type | Description |
| ---- | ---- | ----------- |
| `--outputFormat, --output` | `json \| table \| yaml` | Output format (default: yaml) |
| `--definition` | boolean | Print only the pipeline definition (sources, transforms, sinks) |
| `-v, --version` | string | Pipeline version (default: latest) |

### `goldsky pipeline list`

List all pipelines in the project.

| Flag | Type | Description |
| ---- | ---- | ----------- |
| `--output, --outputFormat` | `json \| table \| yaml` | Output format (default: table) |
| `--outputVerbosity` | `summary \| usablewithapplycmd \| all` | Detail level (default: summary) |
| `--include-runtime-details` | boolean | Include runtime status and errors (default: false) |

```bash
goldsky pipeline list --output json
goldsky pipeline list --include-runtime-details
```

### `goldsky pipeline info <nameOrConfigPath>`

Display pipeline information (status, config, runtime details).

| Flag | Type | Description |
| ---- | ---- | ----------- |
| `-v, --version` | string | Pipeline version (default: latest) |

### `goldsky pipeline monitor <nameOrConfigPath>`

Monitor pipeline runtime — status, metrics (records received/written), errors. Refreshes every 10 seconds.

| Flag | Type | Description |
| ---- | ---- | ----------- |
| `--update-request` | boolean | Monitor an in-flight update request |
| `--max-refreshes, --maxRefreshes` | number | Max number of data refreshes |
| `-v, --version` | string | Pipeline version (default: latest) |

### `goldsky pipeline delete <nameOrConfigPath>`

Delete a pipeline permanently.

| Flag | Type | Description |
| ---- | ---- | ----------- |
| `-f, --force` | boolean | Force deletion without confirmation prompt (default: false) |

### `goldsky pipeline resize <nameOrConfigPath> <resourceSize>`

Change the compute resources for a pipeline.

| Positional | Description |
| ---------- | ----------- |
| `resourceSize` | One of: `s`, `m`, `l`, `xl`, `xxl` (default: `s`) |

```bash
goldsky pipeline resize my-pipeline l
```

### `goldsky pipeline validate [config-path]`

Validate a pipeline YAML config without deploying.

| Flag | Type | Description |
| ---- | ---- | ----------- |
| `--definition` | string | _(deprecated)_ Inline JSON definition |
| `--definition-path` | string | _(deprecated)_ Path to JSON/YAML definition |

```bash
goldsky pipeline validate my-pipeline.yaml
```

### `goldsky pipeline export [name]`

Export pipeline configuration.

| Flag | Type | Description |
| ---- | ---- | ----------- |
| `--all` | boolean | Export configs for all pipelines |

### `goldsky pipeline cancel-update <nameOrConfigPath>`

Cancel an in-flight update or snapshot request. Useful when a long-running snapshot blocks a needed update.

_No additional flags beyond global options._

### `goldsky pipeline create <name>` _(interactive/guided)_

Guided CLI experience for creating a pipeline interactively.

| Flag | Type | Description |
| ---- | ---- | ----------- |
| `--resource-size, --resourceSize` | `s \| m \| l \| xl \| xxl` | Resource size (default: s) |
| `--use-dedicated-ip` | boolean | Use dedicated egress IPs (default: false) |
| `--skip-transform-validation` | boolean | Skip transform validation |
| `--status` | `ACTIVE \| INACTIVE` | _(deprecated, use `pipeline start/stop/pause`)_ |
| `--description` | string | _(deprecated, use `pipeline apply`)_ |
| `--definition` | string | _(deprecated, use `pipeline apply`)_ |
| `--definition-path` | string | _(deprecated, use `pipeline apply`)_ |
| `--output, --outputFormat` | `json \| table \| yaml` | Output format (default: yaml) |

### `goldsky pipeline get-definition <name>` _(deprecated)_

Get a shareable pipeline definition. **Use `goldsky pipeline get <name> --definition` instead.**

### Snapshot Commands

```bash
# List snapshots for a pipeline
goldsky pipeline snapshots list <nameOrConfigPath> [-v <version>]

# Create a snapshot manually
goldsky pipeline snapshots create <nameOrConfigPath>
```

`snapshots list` supports `-v, --version` to filter by pipeline version (default: all versions).

---

## Lifecycle Quick Reference

| Action | Command |
| ------ | ------- |
| Deploy / start | `goldsky pipeline apply <file.yaml> --status ACTIVE` |
| Start (existing) | `goldsky pipeline start <name>` |
| Pause (with snapshot) | `goldsky pipeline pause <name>` |
| Stop (no snapshot) | `goldsky pipeline stop <name>` |
| Restart (no config change) | `goldsky pipeline restart <name> --from-snapshot last` |
| Update config | `goldsky pipeline apply <file.yaml>` (edit YAML first) |
| Resize | `goldsky pipeline resize <name> <size>` |
| Validate YAML | `goldsky pipeline validate <file.yaml>` |
| Monitor | `goldsky pipeline monitor <name>` |
| Get config | `goldsky pipeline get <name> --definition` |
| Export config | `goldsky pipeline export <name>` |
| Delete | `goldsky pipeline delete <name> -f` |
| Cancel in-flight op | `goldsky pipeline cancel-update <name>` |
| List snapshots | `goldsky pipeline snapshots list <name>` |
| Create snapshot | `goldsky pipeline snapshots create <name>` |
| List all pipelines | `goldsky pipeline list` |

**Pause vs. Stop:**
- `pause` — takes a snapshot and suspends the pipeline (status: PAUSED + TERMINATED). Can resume from where it left off.
- `stop` — stops without taking a snapshot (status: INACTIVE + TERMINATED). Resuming may reprocess data.

**Desired statuses:** ACTIVE, INACTIVE, PAUSED
**Runtime statuses:** STARTING, RUNNING, FAILING, TERMINATED

---

## Snapshots

Snapshots capture a point-in-time state of a RUNNING pipeline for resumption. They contain progress on reading sources and SQL transform state — **not** sink state.

- **Automatic snapshots** are taken every 4 hours for healthy RUNNING pipelines.
- **Before updates:** a snapshot is created automatically before applying config changes to a RUNNING pipeline.
- **On pause:** a snapshot is created when pausing.
- **Manual:** `goldsky pipeline snapshots create <name>`.
- **Resume:** only the latest snapshot can be used. For older snapshots, contact support.

The `--from-snapshot` flag (on `apply`, `start`, `restart`) controls snapshot behavior:
- `new` — create a fresh snapshot, then start from it (default)
- `last` — use the latest existing snapshot (no new snapshot)
- `none` — start from scratch, no snapshot
- `<snapshot-id>` — use a specific snapshot

---

## Resource Sizing

Set via `resource_size` in YAML or `goldsky pipeline resize <name> <size>`.

| Size | Description |
| ---- | ----------- |
| `s` | Default. Handles most use cases, backfill of small chains, up to 300K records/sec, up to ~8 subgraph sources |
| `m`, `l`, `xl`, `xxl` | Larger compute — for backfilling large chains or large JOINs |

Start small and scale up if needed. Resource size affects pricing.

---

## Networking

- Mirror pipelines write data from **AWS us-west-2**. Ensure your sink allows inbound connections from this region.
- IP addresses are **dynamic** by default.
- **Dedicated egress IPs** available on request — use `--use-dedicated-ip` on `pipeline create`, or contact support@goldsky.com.
- VPC peering available on request.
- For external handler transforms, deploy close to us-west-2 for best performance (aim for p95 < 100ms).

---

## Dataset Discovery

```bash
# List available datasets
goldsky dataset list

# Get schema for a specific dataset
goldsky dataset get <dataset_name>
```

---

## Common Questions

**Can Mirror pipelines use subgraphs as a source?**
Yes — this is Mirror's primary advantage over Turbo. Set `type: subgraph_entity` in your source and reference your deployed subgraph.

**Can Mirror handle multiple sources or cross-chain data?**
Yes — define multiple sources in the YAML and use SQL transforms to join or merge them. For subgraphs, you can list multiple subgraphs (different chains) in a single source's `subgraphs` array.

**My pipeline needs more resources / is too slow?**
Run `goldsky pipeline resize <name> l` (or `xl`, `xxl`). Start small and scale up.

**My pipeline is ACTIVE but TERMINATED — what happened?**
The desired status is ACTIVE but the runtime failed (e.g., bad secret, sink unavailable, resource issues). Check errors with `goldsky pipeline monitor <name> --include-runtime-details` or view the dashboard. Fix the issue and restart.

**How do I update a pipeline without losing progress?**
Edit your YAML and run `goldsky pipeline apply <file.yaml>`. By default, a snapshot is taken before the update is applied. Use `--from-snapshot last` to skip creating a new snapshot and use the latest existing one.

**A long snapshot is blocking my update — what do I do?**
Run `goldsky pipeline cancel-update <name>` to cancel the in-flight operation, then reapply with `--from-snapshot last` or `--from-snapshot none`.

---

## Related

- **`/turbo-builder`** — Build a new Turbo pipeline (recommended for new projects not using subgraph sources)
- **`/subgraphs`** — Deploy and manage the subgraph you want to sync via Mirror
- **`/secrets`** — Create secrets for sink credentials
- **`/datasets`** — Browse available dataset names and chain prefixes
- **Goldsky docs:** [docs.goldsky.com/mirror/introduction](https://docs.goldsky.com/mirror/introduction)
- **Pipeline config reference:** [docs.goldsky.com/mirror/reference/config-file/pipeline](https://docs.goldsky.com/mirror/reference/config-file/pipeline)
