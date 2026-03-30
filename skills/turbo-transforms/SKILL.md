---
name: turbo-transforms
description: "Write SQL, TypeScript, and dynamic table transforms for Goldsky Turbo pipelines. Use this skill for: decoding EVM event logs with _gs_log_decode (requires ABI) or transaction inputs with _gs_tx_decode, filtering and casting blockchain data in SQL, combining multiple decoded event types into one table with UNION ALL, writing TypeScript/WASM transforms using the invoke(data) function signature, setting up dynamic lookup tables to filter transfers by a wallet list you update at runtime (dynamic_table_check), chaining SQL and TypeScript steps together, or debugging null values in decoded fields. For full pipeline YAML structure, use /turbo-pipelines instead. For building an entire pipeline end-to-end, use /turbo-builder instead."
---

# Turbo Transforms

Write, understand, and debug SQL, TypeScript, and dynamic table transforms for Turbo pipeline configurations.

Identify what the user needs (decode, filter, reshape, combine, custom logic, or lookup joins), then use the relevant section below. If generating a complete pipeline YAML (not just a transform snippet), always validate with `goldsky turbo validate` before presenting it to the user.

**Reference files for specialized topics:**
- `references/sql-functions.md` — Complete Goldsky SQL function reference (decode, hash, U256, array, JSON, time)
- `references/evm-patterns.md` — Advanced EVM patterns (decode-once-filter-many, UNION ALL, schema normalization)
- `references/typescript-transforms.md` — TypeScript/WASM script transforms and handler transforms
- `references/dynamic-tables.md` — Dynamic table transforms (allowlists, lookup joins)
- `references/solana-patterns.md` — Solana instruction/log decoding and function examples

---

## Transform Basics

### YAML Structure

```yaml
transforms:
  my_transform:
    type: sql
    primary_key: id
    sql: |
      SELECT id, block_number, address
      FROM my_source
      WHERE address = '0xabc...'
```

### Required Fields

| Field         | Required | Description                                      |
| ------------- | -------- | ------------------------------------------------ |
| `type`        | Yes      | `sql`, `script`, `handler`, or `dynamic_table`   |
| `primary_key` | Yes      | Column used for uniqueness and ordering           |
| `sql`         | Yes      | SQL query (for `sql` type transforms)            |

### Referencing Data

- Reference **sources** by their YAML key name: `FROM my_source`
- Reference **other transforms** by their YAML key name: `FROM my_transform`
- No need for a `from` field in SQL transforms — the `FROM` clause in SQL handles it

### SQL Streaming Limitations

Turbo SQL is powered by Apache DataFusion in streaming mode. The following are **NOT supported**:

- **Joins** — use `dynamic_table` transforms for lookup-style joins instead
- **Aggregations** (GROUP BY, COUNT, SUM, AVG) — use `postgres_aggregate` sink instead
- **Window functions** (OVER, PARTITION BY, ROW_NUMBER)
- **Subqueries** — use transform chaining instead
- **CTEs** (WITH...AS) **are** supported

### The `_gs_op` Column

Every record includes a `_gs_op` column that tracks the operation type: `'i'` (insert), `'u'` (update), `'d'` (delete). Preserve this column through transforms for correct upsert semantics in database sinks.

---

## Key SQL Functions

Quick reference for the most-used functions. For the complete function reference, read `references/sql-functions.md`.

### `evm_log_decode()` — Decode Raw EVM Logs

```sql
evm_log_decode(abi_json, topics, data) -> STRUCT<name, event_params>
-- Aliases: _gs_log_decode, evm_decode_log
```

Returns `decoded.event_signature` (event name) and `decoded.event_params[N]` (1-indexed parameters as strings).

**Example:**
```sql
SELECT
  _gs_log_decode('[{"anonymous":false,"inputs":[{"indexed":true,"name":"from","type":"address"},{"indexed":true,"name":"to","type":"address"},{"indexed":false,"name":"value","type":"uint256"}],"name":"Transfer","type":"event"}]',
    topics, data) AS decoded,
  id, block_number, transaction_hash, address, block_timestamp
FROM my_raw_logs
```

**Tips:** Backtick-escape reserved words (`` `data` ``, `` `decoded` ``). Include all event ABIs in one array. Pre-filter by contract address at the source level for efficiency.

### Other Key Functions

| Function | Purpose |
| -------- | ------- |
| `fetch_abi(url, format)` | Fetch ABI from URL (`'raw'` or `'etherscan'` format) |
| `_gs_keccak256(string)` | Keccak256 hash (returns hex with `0x` prefix) |
| `xxhash(string)` | Fast non-cryptographic hash for composite keys |
| `to_u256(value)` / `u256_to_string(u256)` | 256-bit integer math (avoids precision loss) |
| `dynamic_table_check(table, value)` | Check if value exists in a dynamic lookup table |
| `to_timestamp(seconds)` | Convert unix seconds to timestamp |

---

## Common Transform Patterns

### Table Aliasing

```sql
SELECT balance.token_type, balance.owner_address,
  CAST(`balance` AS STRING) AS balance_amount
FROM my_balances_source balance
WHERE balance.token_type = 'ERC_20' AND balance.balance IS NOT NULL
```

### Simple Filtering

```yaml
transforms:
  usdc_transfers:
    type: sql
    primary_key: id
    sql: |
      SELECT * FROM base_transfers
      WHERE address = lower('0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913')
```

### Column Projection and Aliasing

```yaml
transforms:
  clean_transfers:
    type: sql
    primary_key: id
    sql: |
      SELECT id, block_number, to_timestamp(block_timestamp) AS block_time,
        address AS token_address, sender, recipient, amount
      FROM my_source
```

### Type Casting and Numeric Scaling

```sql
-- Token amount conversions
(CAST(decoded.event_params[3] AS DOUBLE) / 1e6) AS amount_usdc    -- 6 decimals
(CAST(decoded.event_params[3] AS DOUBLE) / 1e18) AS amount_eth    -- 18 decimals
CAST(`balance` AS STRING) AS balance_amount                        -- preserve precision
```

| Token          | Decimals | Divisor |
| -------------- | -------- | ------- |
| USDC, USDT     | 6        | `1e6`   |
| WBTC           | 8        | `1e8`   |
| ETH, most ERC-20 | 18    | `1e18`  |

### Conditional Logic with CASE WHEN

```sql
CASE WHEN decoded.event_params[4] = '0' THEN 'BUY' ELSE 'SELL' END AS side
```

### Exclusion Filters

```sql
WHERE decoded.event_params[1] NOT IN ('0x4bfb...', '0xc5d5...', '0x4d97...')
```

### Transform Chaining

Build multi-step pipelines where each transform reads from the previous:

```yaml
transforms:
  decoded:
    type: sql
    primary_key: id
    sql: |
      SELECT _gs_log_decode('[...]', topics, data) AS decoded,
        id, block_number, transaction_hash, address, block_timestamp
      FROM raw_logs_source
  transfers:
    type: sql
    primary_key: id
    sql: |
      SELECT id, block_number, decoded.event_params[1] AS from_address,
        decoded.event_params[2] AS to_address,
        (CAST(decoded.event_params[3] AS DOUBLE) / 1e18) AS amount
      FROM decoded
      WHERE decoded.event_signature = 'Transfer'
```

### UNION ALL — Combining Multiple Event Types

Combine transforms with identical schemas into a single output:

```yaml
  all_events:
    type: sql
    primary_key: id
    sql: |
      SELECT * FROM transfers
      UNION ALL
      SELECT * FROM approvals
```

All branches must have the same columns in the same order. Use `''` or `0` as placeholders.

For advanced EVM patterns (decode-once-filter-many, normalizing disparate events, multi-event activity feeds), read `references/evm-patterns.md`.

---

## Source-Level Filtering

Filter data **at the source** before it reaches transforms for efficiency:

```yaml
sources:
  my_logs:
    type: dataset
    dataset_name: matic.raw_logs
    version: 1.0.0
    start_at: earliest
    filter: >-
      address IN ('0xabc...', '0xdef...')
      AND block_number >= 82422949
```

- Source `filter:` → coarse pre-filtering (contract addresses, block ranges)
- Transform `WHERE` → fine-grained filtering (event types, parameter values, exclusions)

---

## Sink Batching Configuration

```yaml
sinks:
  my_sink:
    type: clickhouse
    from: my_transform
    table: my_table
    secret_name: MY_SECRET
    primary_key: id
    batch_size: 1000
    batch_flush_interval: 300ms
```

| Use Case | `batch_flush_interval` | `batch_size` |
| -------- | ---------------------- | ------------ |
| Real-time dashboards | `300ms` | `1000` |
| Moderate throughput | `1000ms` | `1000` |
| High-volume streaming | `10s` | `100000` |

---

## Debugging Transforms

**"Unknown source reference"** — `FROM` clause name doesn't match any source/transform key. Check for typos.

**"Missing primary_key"** — Every transform needs `primary_key`. Almost always use `id`.

**"Column not found"** — Use `goldsky turbo inspect <pipeline> -n <source_node>` to see actual columns.

**Empty results from decoded events:**
- Verify ABI JSON matches actual contract events
- Check `decoded.event_signature` matches event name exactly (case-sensitive)
- Ensure `address` filter matches correct contract
- Parameters are **1-indexed**: `decoded.event_params[1]`, not `[0]`

**Type mismatch in UNION ALL** — All branches need identical column counts and compatible types.

```bash
# Inspect a specific transform's output
goldsky turbo inspect <pipeline-name> -n <transform_name>
```

---

## TypeScript / WASM Script Transforms

For logic SQL can't express: custom parsing, BigInt arithmetic, stateful processing. Schema types: `string`, `uint64`, `int64`, `float64`, `boolean`, `bytes`.

Key rules: define `function invoke(data)`, return `null` to filter, return object matching schema, no async/await or external imports.

See `references/typescript-transforms.md` for full docs, examples, and the SQL-vs-script decision table. Also includes Handler transforms for HTTP enrichment.

---

## Dynamic Table Transforms

Updatable lookup tables for allowlists, blocklists, and join-style enrichment — without redeploying. Backed by PostgreSQL (durable) or in-memory (fast). Use `dynamic_table_check('table_name', column)` in SQL.

See `references/dynamic-tables.md` for full config, backend options, REST API updates, and wallet-tracking example.

---

## Solana Transform Patterns

IDL-based instruction decoding, program-specific decoders (Token, System, Stake, Vote), SPL token tracking.

See `references/solana-patterns.md` for all built-in decoders, full example pipeline, and array/JSON/hex function usage.

---

## Related

- **`/turbo-builder`** — Build and deploy pipelines interactively using these transforms
- **`/turbo-doctor`** — Diagnose and fix pipeline issues (including transform errors)
- **`/turbo-pipelines`** — Pipeline YAML configuration and architecture reference
- **`/turbo-operations`** — Lifecycle commands and monitoring reference
- **`/datasets`** — Blockchain dataset and chain prefix reference
