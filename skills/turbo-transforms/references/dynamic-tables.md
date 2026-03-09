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

| Backend      | `backend_type` | Persistence         | Use Case                                    |
| ------------ | -------------- | ------------------- | ------------------------------------------- |
| PostgreSQL   | `Postgres`     | Durable (database)  | Shared across restarts, externally updatable |
| In-memory    | `InMemory`     | Ephemeral           | Auto-populated from SQL, fast lookups        |

> Note: `Postgres` and `InMemory` are case-sensitive. Use the exact values shown above.

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
