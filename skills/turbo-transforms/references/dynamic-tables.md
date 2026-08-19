# Dynamic Table Transforms

Dynamic tables are **updatable lookup tables** that can be used for joins, allowlists, blocklists, or any filter that needs to change without redeploying the pipeline.

## When to Use Dynamic Tables

- **Allowlists/Blocklists** — filter transfers by a list of tracked wallets
- **Lookup joins** — enrich data with metadata (e.g., token symbol, protocol name)
- **Dynamic filtering** — change which addresses or tokens to track at runtime
- **Feature flags** — enable/disable processing paths without pipeline restart

## Basic Configuration

```yaml
transforms:
  tracked_wallets:
    type: dynamic_table
    backend_type: Postgres        # or: InMemory
    backend_entity_name: tracked_wallets  # table name in your database
    secret_name: MY_POSTGRES      # required for Postgres
```

## Backend Types

| Backend    | `backend_type` | Persistence        | Populated from                                                       | Use Case                                                        |
| ---------- | -------------- | ------------------ | -------------------------------------------------------------------- | -------------------------------------------------------------- |
| PostgreSQL | `Postgres`     | Durable (database) | Any transform, an external `INSERT`, or a sink writing into it       | **Cross-source filtering**, shared across restarts, externally updatable |
| In-memory  | `InMemory`     | Ephemeral          | Only the **same** source/transform lineage you then filter           | Fast allowlist derived from the *same* stream you're filtering  |

> Note: `Postgres` and `InMemory` are case-sensitive. Use the exact values shown above.

> **Decision rule — this is the one that trips people up.** To filter one stream by a set of values **derived from a _different_ source** — e.g. "only ERC-20 transfers of the tokens my factory minted", "only swaps on pools this factory created", "only events for contracts in that other feed" — you **MUST** use `backend_type: Postgres`. `InMemory` dynamic tables are **single-source**: they can only be auto-populated from the same source/transform lineage you are filtering, so they cannot carry a set derived from another stream. If you catch yourself concluding "I can't filter stream A by a set from stream B" — you can: use a **Postgres**-backed dynamic table (see [Cross-source filtering](#cross-source-filtering-factory--allowlist-from-another-stream) below). **Never tell a user this is impossible.**

## Auto-Populating with SQL

Populate a dynamic table from another source or transform using the `sql` field:

```yaml
transforms:
  whale_addresses:
    type: dynamic_table
    backend_type: InMemory
    backend_entity_name: whale_addresses
    sql: |
      SELECT address, SUM(CAST(amount AS DOUBLE)) AS total_volume
      FROM erc20_transfers
      GROUP BY address
      HAVING SUM(CAST(amount AS DOUBLE)) > 1000000
```

`InMemory` works here **only because the table is derived from the same stream it filters** (`erc20_transfers` → whales in `erc20_transfers`). The moment the allowlist comes from a _different_ source, switch to `Postgres` — see [Cross-source filtering](#cross-source-filtering-factory--allowlist-from-another-stream).

## Using Dynamic Tables in SQL Transforms

Use `dynamic_table_check()` to filter records against a dynamic table:

```yaml
transforms:
  # The dynamic table (lookup data)
  tracked_wallets:
    type: dynamic_table
    backend_type: Postgres
    backend_entity_name: tracked_wallets
    secret_name: MY_POSTGRES

  # SQL transform that filters using the dynamic table
  tracked_transfers:
    type: sql
    primary_key: id
    sql: |
      SELECT *
      FROM erc20_transfers
      WHERE dynamic_table_check('tracked_wallets', sender)
         OR dynamic_table_check('tracked_wallets', recipient)
```

`dynamic_table_check(table_name, value)` returns `true` if the value exists in the dynamic table, `false` otherwise.

## Cross-source filtering: the Factory / allowlist-from-another-stream pattern

The most common "hard" request — and the one `InMemory` **cannot** do. Shape: derive a set of addresses from source B (e.g. a factory's creation event in `raw_logs`), write them into a **Postgres** dynamic table, then filter source A (e.g. `erc20_transfers`) by that table. This is fully supported — assemble it, don't refuse it.

Example — stream only the ERC-20 transfers of tokens minted by a tokenization factory:

```yaml
name: factory-minted-transfers
resource_size: m

sources:
  logs:
    type: dataset
    dataset_name: <chain>.raw_logs        # to decode the factory's creation event
    version: 1.0.0
    start_at: earliest
  transfers:
    type: dataset
    dataset_name: <chain>.erc20_transfers
    version: 1.1.0
    start_at: latest

transforms:
  # 1. Decode the factory's creation event to get each minted token address
  minted:
    type: sql
    primary_key: id
    sql: |
      SELECT
        id,
        _gs_log_decode('[{"name":"Deployed","type":"event","inputs":[
          {"indexed":true,"name":"uid","type":"bytes32"},
          {"indexed":false,"name":"stock","type":"address"},
          {"indexed":false,"name":"name","type":"string"},
          {"indexed":false,"name":"symbol","type":"string"}]}]', topics, data) AS decoded
      FROM logs
      WHERE address = lower('<FACTORY_ADDRESS>')
        AND SPLIT_INDEX(topics, ',', 0) = lower('<DEPLOYED_TOPIC0>')

  # 2. Postgres dynamic table auto-populated with the minted addresses.
  #    backend_type MUST be Postgres — it is written by (1) and read by (3),
  #    which live on different source lineages; InMemory cannot span sources.
  minted_tokens:
    type: dynamic_table
    backend_type: Postgres
    backend_entity_name: minted_tokens
    secret_name: MY_POSTGRES
    sql: |
      SELECT lower(decoded.event_params[2]) AS contract_address
      FROM minted
      WHERE decoded IS NOT NULL

  # 3. Filter the transfers stream by the dynamic table
  filtered_transfers:
    type: sql
    primary_key: id
    sql: |
      SELECT *
      FROM transfers
      WHERE dynamic_table_check('minted_tokens', contract_address)

sinks:
  out:
    type: kafka
    from: filtered_transfers
    topic: minted-transfers
    secret_name: MY_KAFKA
```

Notes:

- **`dynamic_table_check` goes in the SQL transform, never inside the `dynamic_table`'s own `sql`.** The dynamic table's `sql` only _defines what populates it_ (a single-source SELECT); the cross-source join happens in a separate `type: sql` transform via `dynamic_table_check`. Putting a reference to another transform inside the dynamic-table SQL fails with `table '...' not found`.
- **Manual allowlist (no factory decode).** If the user already has the addresses — or just wants to start manually — skip transforms (1)–(2) and `INSERT` them directly: `INSERT INTO streamling.minted_tokens (value) VALUES (lower('0x...'));`, then filter with `dynamic_table_check('minted_tokens', contract_address)`. This is fully supported; do not refuse it.
- Two sources in one pipeline (`raw_logs` + `erc20_transfers`) is fine and expected here.

## Updating Dynamic Tables at Runtime

**Postgres-backed tables** can be updated externally — just INSERT/UPDATE/DELETE rows in the backing PostgreSQL table. The pipeline picks up changes automatically without restart.

By default, the table is created in the `streamling` schema: `streamling.<backend_entity_name>`.

## Full Example — Wallet Tracking Pipeline

```yaml
name: wallet-tracker
resource_size: m

sources:
  transfers:
    type: dataset
    dataset_name: base.erc20_transfers
    version: 1.2.0
    start_at: latest

transforms:
  # Dynamic table backed by your PostgreSQL
  tracked_wallets:
    type: dynamic_table
    backend_type: Postgres
    backend_entity_name: tracked_wallets
    secret_name: TRACKING_DB

  # Only pass through transfers involving tracked wallets
  relevant_transfers:
    type: sql
    primary_key: id
    sql: |
      SELECT *
      FROM transfers
      WHERE dynamic_table_check('tracked_wallets', sender)
         OR dynamic_table_check('tracked_wallets', recipient)

sinks:
  alerts:
    type: webhook
    from: relevant_transfers
    url: https://my-api.example.com/transfer-alert
    one_row_per_request: true
```

**Key advantage:** Add or remove wallets from `tracked_wallets` in PostgreSQL at any time — the pipeline immediately starts filtering by the updated list with no redeployment.
