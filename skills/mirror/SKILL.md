---
name: mirror
description: "Use this skill when the user asks about Goldsky Mirror pipelines — creating, deploying, operating, or understanding Mirror. Triggers on: 'how do I create a Mirror pipeline', 'how do I sync my subgraph to a database', 'goldsky pipeline apply', 'mirror pipeline sources sinks', 'mirror vs turbo', 'direct indexing mirror', 'mirror pipeline YAML'. Mirror is the legacy/v1 streaming pipeline product. For questions that are purely about Turbo pipelines, use the turbo-* skills instead."
---

# Goldsky Mirror Pipelines

Mirror is Goldsky's original streaming pipeline product. It reads onchain data from a **source** (a subgraph or a direct-indexing dataset), optionally applies **transforms**, and writes the result to a **sink** (your database or message queue).

> **Should you use Mirror or Turbo?**
> **Turbo is the recommended choice for new pipelines.** It's faster, uses a simpler YAML config, and supports 130+ chains with richer datasets. Use Mirror if:
> - You need to sync an existing Goldsky **subgraph** into a database (Mirror supports subgraph sources; Turbo does not).
> - You already have a Mirror pipeline you're maintaining.
>
> If your use case doesn't require a subgraph source, say "help me build a Turbo pipeline" and the turbo-builder skill will guide you through a faster setup.

---

## How Mirror Pipelines Work

```
Source (subgraph or direct-indexing dataset)
  ↓
Transforms (optional SQL or external handlers)
  ↓
Sink (PostgreSQL, ClickHouse, Kafka, S3, etc.)
```

A pipeline is defined in a YAML file and deployed with `goldsky pipeline apply`.

---

## Sources

| Source type | Description | When to use |
| ----------- | ----------- | ----------- |
| **Subgraph** | Mirror data from any Goldsky-hosted subgraph | You have a subgraph and want to sync it to a DB |
| **Direct indexing** | Raw onchain datasets (blocks, transactions, logs, transfers) | You want raw chain data without writing a subgraph |

See [docs.goldsky.com/mirror/sources/supported-sources](https://docs.goldsky.com/mirror/sources/supported-sources).

---

## Sinks

Mirror supports the following destinations:

| Sink | Notes |
| ---- | ----- |
| **PostgreSQL** | Most common — write to any Postgres-compatible DB |
| **ClickHouse** | For real-time analytics / OLAP workloads |
| **Kafka** | Stream records to a Kafka topic |
| **S3** | Write to an S3-compatible object store |
| **MySQL** | Write to a MySQL-compatible DB |
| **Webhook** | POST records to an HTTP endpoint |

See [docs.goldsky.com/mirror/sinks/supported-sinks](https://docs.goldsky.com/mirror/sinks/supported-sinks).

---

## Pipeline YAML

Mirror pipelines are configured in YAML. The two key fields are the sources and sinks sections. Example — syncing a subgraph to PostgreSQL:

```yaml
sources:
  my_subgraph:
    type: subgraph
    subgraph_id: <your-subgraph-id>
    entity: Transfer

sinks:
  my_postgres:
    type: postgres
    table: transfers
    schema: public
    secret_name: MY_PG_SECRET
    from: my_subgraph
```

Example — direct indexing (raw chain data) to PostgreSQL:

```yaml
sources:
  base_transfers:
    type: dataset
    dataset_name: base.erc20_transfers
    version: 1.2.0
    start_at: latest

sinks:
  my_postgres:
    type: postgres
    table: erc20_transfers
    schema: public
    secret_name: MY_PG_SECRET
    from: base_transfers
```

> For direct indexing, if you don't need a subgraph, **Turbo is strongly preferred** — it has a richer dataset catalog and simpler syntax. Use `/turbo-builder` to get started.

---

## Deploy a Mirror Pipeline

```bash
# Apply (create or update) a pipeline
goldsky pipeline apply my-pipeline.yaml --status ACTIVE

# List pipelines
goldsky pipeline list

# View pipeline details
goldsky pipeline get <name>
```

---

## Lifecycle Commands

| Action | Command |
| ------ | ------- |
| Apply / deploy | `goldsky pipeline apply <file.yaml> --status ACTIVE` |
| Pause | `goldsky pipeline pause <name>` |
| Stop | `goldsky pipeline stop <name>` |
| Restart | `goldsky pipeline restart <name>` |
| Delete | `goldsky pipeline delete <name>` |
| List all | `goldsky pipeline list` |

**Pause vs. Stop:**
- `pause` — takes a snapshot and suspends the pipeline so it can be resumed from where it left off.
- `stop` — stops the pipeline without taking a snapshot; resuming may reprocess some data.

---

## Transforms

Mirror supports two transform types:

| Type | Description |
| ---- | ----------- |
| **SQL** | Filter, join, or reshape records with SQL |
| **External handler** | POST records to an HTTP endpoint for custom logic |

See [docs.goldsky.com/mirror/transforms/sql-transforms](https://docs.goldsky.com/mirror/transforms/sql-transforms).

---

## Common Questions

**Can Mirror pipelines use subgraphs as a source?**
Yes — this is Mirror's primary advantage over Turbo. Set `type: subgraph` in your source.

**Can Mirror handle multiple sources or cross-chain data?**
Yes — define multiple sources in the YAML and use SQL transforms to join or merge them.

**Mirror says my pipeline is too large / needs more resources?**
Add `--resource-size <size>` to your `goldsky pipeline create` command. Valid sizes: `small`, `medium`, `large`.

**Where do Mirror pipelines write from?**
Mirror pipelines run in `us-west-2`. Ensure your sink allows inbound connections from AWS us-west-2.

---

## Related

- **`/turbo-builder`** — Build a new Turbo pipeline (recommended for new projects not using subgraph sources)
- **`/subgraphs`** — Deploy and manage the subgraph you want to sync via Mirror
- **Goldsky docs:** [docs.goldsky.com/mirror/introduction](https://docs.goldsky.com/mirror/introduction)
