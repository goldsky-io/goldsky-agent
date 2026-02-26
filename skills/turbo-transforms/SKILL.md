---
name: turbo-transforms
description: Write and understand SQL, TypeScript, and dynamic table transforms for Turbo pipelines. Use when decoding EVM/Solana logs, filtering events, casting types, chaining transforms, combining data with UNION ALL, writing TypeScript/WASM logic, configuring dynamic lookup tables, or building complex data processing logic.
---

# Turbo Transforms

Write, understand, and debug SQL, TypeScript, and dynamic table transforms for Turbo pipeline configurations.

## Triggers

Invoke this skill when the user:

- Asks "how do transforms work" or "what can I do with transforms"
- Wants to decode raw EVM logs or contract events
- Needs to filter, reshape, or combine blockchain data
- Asks about `evm_log_decode`, `_gs_log_decode`, U256/I256 math, or other Goldsky SQL functions
- Wants to chain multiple transforms together
- Needs help writing SQL for a pipeline YAML
- Is debugging a transform that isn't producing expected results
- Wants to combine multiple event types into a single output
- Asks about TypeScript transforms, WASM scripts, or custom logic beyond SQL
- Wants to use dynamic tables for lookup joins or allowlists/blocklists
- Asks about Solana instruction decoding or program-specific decoders
- Mentions `/turbo-transforms`

## Agent Instructions

### Step 1: Understand What the User Needs

Determine the transform goal:

- **Decode raw logs** → Guide them through ABI-based log decoding with `evm_log_decode()`
- **Decode Solana data** → Guide through IDL-based instruction/log decoding or program-specific decoders
- **Filter data** → Help write WHERE clauses (address, event type, block range, etc.)
- **Reshape columns** → Help with SELECT, CAST, CASE WHEN, string manipulation
- **Combine data** → Help with UNION ALL across multiple event types or sources
- **Chain transforms** → Help build multi-step processing pipelines
- **Custom logic beyond SQL** → Guide them through TypeScript/WASM script transforms
- **Lookup joins / dynamic filtering** → Guide through dynamic table transforms
- **Understand existing transforms** → Walk through the SQL and explain each part

### Step 2: Write or Explain the Transform

Use the patterns and references below to help the user. Always ensure:

1. Every transform has `type: sql` and `primary_key: id` (or appropriate column)
2. SQL references source or transform names in the `FROM` clause
3. Column names match the source schema
4. CAST operations use correct target types (DOUBLE, VARCHAR, etc.)

### Step 3: Validate

> **CRITICAL:** After writing transforms, always validate the full pipeline YAML:
> ```bash
> goldsky turbo validate <pipeline.yaml>
> ```

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

## Goldsky SQL Functions

### `evm_log_decode()` — Decode Raw EVM Logs

Decodes raw Ethereum log data into structured event fields using an ABI specification.

> **Aliases:** `_gs_log_decode` and `evm_decode_log` also work. Existing pipelines using `_gs_log_decode` are valid.

**Syntax:**
```sql
evm_log_decode(abi_json, topics, data) -> STRUCT<name: VARCHAR, event_params: LIST<VARCHAR>>
```

**Parameters:**
- `abi_json` — JSON string containing the ABI event definitions (or full contract ABI)
- `topics` — The `topics` column from `raw_logs`
- `data` — The `data` column from `raw_logs`

**Returns a struct with:**
- `decoded.name` (or `decoded.event_signature` via alias) — Event name (e.g., `'OrderFilled'`, `'Transfer'`)
- `decoded.event_params[N]` — Positional event parameters (1-indexed, returned as strings)

**Example — Decode ERC-20 Transfer events:**
```yaml
transforms:
  decoded_events:
    type: sql
    primary_key: id
    sql: |
      SELECT
        _gs_log_decode(
          '[{"anonymous":false,"inputs":[{"indexed":true,"name":"from","type":"address"},{"indexed":true,"name":"to","type":"address"},{"indexed":false,"name":"value","type":"uint256"}],"name":"Transfer","type":"event"}]',
          topics,
          data
        ) AS decoded,
        id,
        block_number,
        transaction_hash,
        address,
        block_timestamp
      FROM my_raw_logs
```

**Then filter by event in a downstream transform:**
```yaml
  transfers:
    type: sql
    primary_key: id
    sql: |
      SELECT
        id,
        block_number,
        block_timestamp,
        transaction_hash,
        address AS token_address,
        decoded.event_params[1] AS from_address,
        decoded.event_params[2] AS to_address,
        (CAST(decoded.event_params[3] AS DOUBLE) / 1e18) AS amount
      FROM decoded_events
      WHERE decoded.event_signature = 'Transfer'
```

**Tips for `_gs_log_decode()`:**
- The ABI JSON must be a **single-line string** or use YAML `>-` / `|` block syntax
- Include **all event ABIs** you want to decode in a single array — events not matching are ignored
- Multiple events with the same name but different signatures (e.g., from different contracts) can coexist
- Use the source's `filter:` field to pre-filter by contract address before decoding (more efficient)
- **Backtick-escape reserved words:** Several column names conflict with SQL reserved words and must be escaped with backticks: `` `data` ``, `` `decoded` ``, `` `balance` ``, `` `owner_address` ``, `` `id` `` (in some contexts). When in doubt, backtick-escape column names that could be keywords.

**Correct escaping example:**
```sql
SELECT
  _gs_log_decode('[...]', topics, `data`) AS `decoded`,
  id, block_number, transaction_hash, address, block_timestamp
FROM my_raw_logs
```

### `fetch_abi()` — Fetch ABI/IDL from URL

Fetch an ABI or IDL from a remote URL. Cached internally for performance.

```sql
fetch_abi(url, format) -> VARCHAR
-- format: 'raw' for plain JSON, 'etherscan' for Etherscan API responses
```

**Aliases:** `_gs_fetch_abi`

**Example:**
```sql
evm_log_decode(
  fetch_abi('https://example.com/erc20.json', 'raw'),
  topics, data
) AS decoded
```

### `_gs_keccak256()` — Keccak256 Hash

Compute Keccak256 hash (same as Solidity's `keccak256`). Returns hex with `0x` prefix.

```sql
_gs_keccak256('Transfer(address,address,uint256)')
-- 0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef
```

### `xxhash()` — Fast Non-Cryptographic Hash

```sql
xxhash(concat(transaction_hash, '_', log_index::VARCHAR)) AS unique_id
```

### U256/I256 — 256-bit Integer Math

For precise token amount arithmetic without JavaScript precision loss.

```sql
-- Convert to/from U256
to_u256(value)              -> U256
u256_to_string(u256_value)  -> VARCHAR

-- Arithmetic (also available: u256_sub, u256_mul, u256_div, u256_mod)
u256_add(a, b) -> U256

-- Automatic operator rewriting: once values are cast to U256/I256,
-- standard operators (+, -, *, /, %) are auto-rewritten to function calls
to_u256(value) / to_u256('1000000000000000000')  -- same as u256_div(...)
```

**I256 (signed):** `to_i256`, `i256_to_string`, `i256_add`, `i256_sub`, `i256_mul`, `i256_div`, `i256_mod`, `i256_neg`, `i256_abs`

**Example — Convert wei to ETH:**
```sql
u256_to_string(
  to_u256(evt.event_params[3]) / to_u256('1000000000000000000')
) AS amount_eth
```

### Solana Decode Functions

```sql
-- Decode instruction data using IDL (returns STRUCT<name, value>)
_gs_decode_instruction_data(idl_json, data)

-- Decode program log messages using IDL
_gs_decode_log_message(idl_json, log_messages)

-- Program-specific decoders:
gs_solana_decode_token_program_instruction(data)
gs_solana_decode_system_program_instruction(data)
gs_solana_get_accounts(transaction_data)
gs_solana_get_balance_changes(transaction_data)
gs_solana_decode_associated_token_program_instruction(data)
gs_solana_decode_stake_program_instruction(data)
gs_solana_decode_vote_program_instruction(data)

-- Base58 decoding
_gs_from_base58(base58_string) -> BINARY
```

### Array Functions

```sql
-- Filter array elements by struct field matching a list of values
-- (prevents overflow panics by filtering BEFORE unnest)
array_filter_in(array, field_name, values_list) -> LIST

-- Convert list to large-list (i64 offsets) for very large arrays
to_large_list(array) -> LARGE_LIST

-- Filter array by field value
array_filter(array, field_name, value) -> LIST

-- Get first matching element
array_filter_first(array, field_name, value) -> STRUCT

-- Add index to each element
array_enumerate(array) -> LIST<STRUCT<index, value>>

-- Combine multiple arrays element-wise
zip_arrays(array1, array2, ...) -> LIST<STRUCT>
```

### JSON Functions

```sql
json_query(json_string, path) -> VARCHAR       -- Query JSON by path
json_value(json_string, path) -> VARCHAR       -- Extract scalar value
json_exists(json_string, path) -> BOOLEAN      -- Check path exists
is_json(string) -> BOOLEAN                     -- Validate JSON
parse_json(json_string) -> JSON                -- Parse (errors on invalid)
try_parse_json(json_string) -> JSON            -- Parse (NULL on invalid)
json_object(key1, val1, ...) -> JSON           -- Construct JSON object
json_array(val1, val2, ...) -> JSON            -- Construct JSON array
```

### Time Functions

```sql
to_timestamp(seconds) -> TIMESTAMP
to_timestamp_micros(microseconds) -> TIMESTAMP
now() -> TIMESTAMP                              -- volatile, current time
date_part('hour', timestamp) -> INT             -- extract timestamp parts
```

### `dynamic_table_check()` — Lookup Table Check

Check if a value exists in a dynamic table (async). Used with `dynamic_table` transforms.

```sql
WHERE dynamic_table_check('tracked_wallets', from_address)
```

### String & Encoding Functions

```sql
_gs_hex_to_byte(hex_string) -> BINARY
_gs_byte_to_hex(bytes) -> VARCHAR
string_to_array(string, delimiter) -> LIST<VARCHAR>
regexp_extract(string, pattern, group_index) -> VARCHAR
regexp_replace(string, pattern, replacement) -> VARCHAR
```

### Standard SQL Functions

All Apache DataFusion SQL functions are also available: `lower`, `upper`, `trim`, `substring`, `concat`, `replace`, `reverse`, `COALESCE`, `CASE WHEN`, `CAST`, etc.

```sql
-- Common patterns
lower('0xABC...')                              -- case-insensitive address
CONCAT('base', '-', COALESCE(addr, ''))        -- composite keys
COALESCE(balance.contract_address, '')         -- null-safe values
to_timestamp(block_timestamp) AS block_time    -- timestamp conversion
```

---

## Common Transform Patterns

### 1. Table Aliasing

Use table aliases to reference columns clearly, especially when column names are ambiguous:

```sql
SELECT
  balance.token_type,
  balance.owner_address,
  contract_address AS token_address,
  CAST(`balance` AS STRING) AS balance_amount
FROM my_balances_source balance
WHERE balance.token_type = 'ERC_20'
  AND balance.balance IS NOT NULL
```

**Null checks:** Use `IS NULL` and `IS NOT NULL` to filter on nullable columns:
```sql
WHERE balance.token_type IS NULL    -- native token (no token type)
WHERE balance.balance IS NOT NULL   -- only rows with a balance value
```

### 2. Simple Filtering (WHERE)

Filter rows from a source by column values:

```yaml
transforms:
  usdc_transfers:
    type: sql
    primary_key: id
    sql: |
      SELECT *
      FROM base_transfers
      WHERE address = lower('0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913')
```

### 3. Column Projection and Aliasing

Select and rename specific columns:

```yaml
transforms:
  clean_transfers:
    type: sql
    primary_key: id
    sql: |
      SELECT
        id,
        block_number,
        to_timestamp(block_timestamp) AS block_time,
        address AS token_address,
        sender,
        recipient,
        amount
      FROM my_source
```

### 4. Type Casting and Numeric Scaling

Cast values between types. Supported CAST targets include `DOUBLE`, `STRING`, `VARCHAR`, `DECIMAL(p,s)`, `INT`, `BIGINT`.

```sql
-- Convert from raw uint256 to human-readable amounts
(CAST(decoded.event_params[3] AS DOUBLE) / 1e6) AS amount_usdc    -- 6 decimals (USDC)
(CAST(decoded.event_params[3] AS DOUBLE) / 1e18) AS amount_eth    -- 18 decimals (ETH, most ERC-20s)
(CAST(decoded.event_params[3] AS DOUBLE) / 1e8) AS amount_btc     -- 8 decimals (WBTC)

-- Cast to STRING to preserve precision for very large numbers (e.g., raw balances)
CAST(`balance` AS STRING) AS balance_amount
```

Common decimal places by token:

| Token          | Decimals | Divisor |
| -------------- | -------- | ------- |
| USDC, USDT     | 6        | `1e6`   |
| WBTC           | 8        | `1e8`   |
| ETH, most ERC-20 | 18    | `1e18`  |

### 5. Conditional Logic with CASE WHEN

Derive new columns based on conditions:

```sql
-- Determine trade side based on asset type
CASE WHEN decoded.event_params[4] = '0' THEN 'BUY' ELSE 'SELL' END AS side

-- Conditional amount extraction
(CASE
  WHEN decoded.event_params[4] = '0'
  THEN CAST(decoded.event_params[6] AS DOUBLE)
  ELSE CAST(decoded.event_params[7] AS DOUBLE)
END / 1e6) AS amount_usdc

-- Classify transaction types
CASE
  WHEN decoded.event_params[3] = '0x4bfb...' THEN 'taker'
  WHEN decoded.event_params[3] = '0xc5d5...' THEN 'taker'
  ELSE 'maker'
END AS order_type
```

### 6. String Manipulation

```sql
-- Prepend '0x' to hex values from decoded params
'0x' || decoded.event_params[4] AS condition_id

-- Static string values
'TRADE' AS tx_type
'' AS placeholder_field
```

### 7. Exclusion Filters

Exclude known contract/system addresses from user-facing data:

```sql
WHERE decoded.event_params[1] NOT IN (
  '0x4bfb41d5b3570defd03c39a9a4d8de6bd8b8982e',
  '0xc5d563a36ae78145c45a50134d48a1215220f80a',
  '0x4d97dcd97ec945f40cf65f87097ace5ea0476045'
)
```

### 8. Price Calculations

Derive price from filled amounts:

```sql
-- price = cost / quantity
(CASE
  WHEN decoded.event_params[4] = '0'
  THEN CAST(decoded.event_params[6] AS DOUBLE)
  ELSE CAST(decoded.event_params[7] AS DOUBLE)
END / CASE
  WHEN decoded.event_params[4] = '0'
  THEN CAST(decoded.event_params[7] AS DOUBLE)
  ELSE CAST(decoded.event_params[6] AS DOUBLE)
END) AS price
```

---

## Advanced Patterns

### Decode Once, Filter Many

When working with raw logs from multiple contract events, decode **all events in a single transform** and then create separate downstream transforms that filter by `decoded.event_signature`. This is more efficient than creating multiple decode transforms.

```yaml
transforms:
  # Single decode step — include ALL event ABIs
  all_decoded:
    type: sql
    primary_key: id
    sql: |
      SELECT
        _gs_log_decode('[...full ABI with all events...]', topics, `data`) AS `decoded`,
        id, block_number, transaction_hash, address, block_timestamp
      FROM raw_logs_source

  # Downstream: each transform filters for one event type
  transfers:
    type: sql
    primary_key: id
    sql: |
      SELECT id, block_number, decoded.event_params[1] AS from_addr, ...
      FROM all_decoded
      WHERE decoded.event_signature = 'Transfer'

  approvals:
    type: sql
    primary_key: id
    sql: |
      SELECT id, block_number, decoded.event_params[1] AS owner, ...
      FROM all_decoded
      WHERE decoded.event_signature = 'Approval'
```

Even if you only need one event type downstream, it's fine to include the full ABI — unmatched events are simply ignored by the downstream WHERE filter.

### Transform Chaining

Build multi-step pipelines where each transform reads from the previous one:

```yaml
transforms:
  # Step 1: Decode raw logs
  decoded:
    type: sql
    primary_key: id
    sql: |
      SELECT
        _gs_log_decode('[...]', topics, data) AS decoded,
        id, block_number, transaction_hash, address, block_timestamp
      FROM raw_logs_source

  # Step 2: Extract specific event fields
  transfers:
    type: sql
    primary_key: id
    sql: |
      SELECT
        id, block_number, block_timestamp, transaction_hash,
        decoded.event_params[1] AS from_address,
        decoded.event_params[2] AS to_address,
        (CAST(decoded.event_params[3] AS DOUBLE) / 1e18) AS amount
      FROM decoded
      WHERE decoded.event_signature = 'Transfer'

  # Step 3: Add computed columns
  enriched_transfers:
    type: sql
    primary_key: id
    sql: SELECT *, 'ethereum' AS chain FROM transfers
```

### UNION ALL — Combining Multiple Event Types

Combine multiple transforms with identical schemas into a single output. Every SELECT in the UNION must have the **exact same columns in the same order**.

```yaml
transforms:
  # Individual event transforms (each with identical output columns)
  transfers:
    type: sql
    primary_key: id
    sql: |
      SELECT id, block_number, block_timestamp, transaction_hash,
        decoded.event_params[1] AS user_id,
        (CAST(decoded.event_params[3] AS DOUBLE) / 1e18) AS amount,
        'TRANSFER' AS event_type
      FROM decoded_events
      WHERE decoded.event_signature = 'Transfer'

  approvals:
    type: sql
    primary_key: id
    sql: |
      SELECT id, block_number, block_timestamp, transaction_hash,
        decoded.event_params[1] AS user_id,
        (CAST(decoded.event_params[3] AS DOUBLE) / 1e18) AS amount,
        'APPROVAL' AS event_type
      FROM decoded_events
      WHERE decoded.event_signature = 'Approval'

  # Combined output
  all_events:
    type: sql
    primary_key: id
    sql: |
      SELECT * FROM transfers
      UNION ALL
      SELECT * FROM approvals
```

**UNION ALL rules:**
- All SELECTs must produce the **same number of columns** with **compatible types**
- Use empty strings (`''`) or zero (`0`) as placeholders for columns that don't apply to a particular event type
- `UNION ALL` keeps duplicates (use `UNION` to deduplicate, but `UNION ALL` is preferred for performance)
- You can UNION as many transforms as needed

### Normalizing Disparate Events to a Common Schema

When different events have different fields, map them all to a unified schema using placeholder values:

```yaml
transforms:
  trades:
    type: sql
    primary_key: id
    sql: |
      SELECT id, block_number, block_timestamp, transaction_hash, address,
        decoded.event_params[2] AS user_id,
        decoded.event_params[4] AS asset,
        '' AS condition_id,                    -- not applicable for trades
        (CAST(decoded.event_params[6] AS DOUBLE) / 1e6) AS amount_usdc,
        'TRADE' AS tx_type,
        CASE WHEN decoded.event_params[4] = '0' THEN 'BUY' ELSE 'SELL' END AS side,
        (CAST(decoded.event_params[8] AS DOUBLE) / 1e6) AS fee
      FROM decoded_events
      WHERE decoded.event_signature = 'OrderFilled'

  redemptions:
    type: sql
    primary_key: id
    sql: |
      SELECT id, block_number, block_timestamp, transaction_hash, address,
        decoded.event_params[1] AS user_id,
        '' AS asset,                           -- not applicable for redemptions
        '0x' || decoded.event_params[4] AS condition_id,
        (CAST(decoded.event_params[6] AS DOUBLE) / 1e6) AS amount_usdc,
        'REDEEM' AS tx_type,
        '' AS side,                            -- not applicable for redemptions
        0 AS fee                               -- no fee for redemptions
      FROM decoded_events
      WHERE decoded.event_signature = 'PayoutRedemption'

  all_activities:
    type: sql
    primary_key: id
    sql: |
      SELECT * FROM trades
      UNION ALL
      SELECT * FROM redemptions
```

### Adding Columns to an Existing Transform

Extend a transform's output without rewriting it:

```yaml
  activities_v2:
    type: sql
    primary_key: id
    sql: SELECT *, '' AS builder FROM all_activities
```

---

## Source-Level Filtering

For efficiency, filter data **at the source** before it reaches transforms. Use the `filter:` field on dataset sources to reduce the volume of data processed:

```yaml
sources:
  my_logs:
    type: dataset
    dataset_name: matic.raw_logs
    version: 1.0.0
    start_at: earliest
    filter: >-
      address IN ('0xabc...', '0xdef...')
      AND block_number > 50000000
```

This is significantly more efficient than filtering in a transform because it reduces data at the ingestion layer.

### Bounded Historical Backfill

To process historical data starting from a specific block (not genesis), combine `start_at: earliest` with a `block_number` floor in the filter:

```yaml
sources:
  poly_logs:
    type: dataset
    dataset_name: matic.raw_logs
    version: 1.0.0
    start_at: earliest
    filter: >-
      address IN ('0xabc...', '0xdef...')
      AND block_number >= 82422949
```

This processes all data from block 82422949 onward, rather than from genesis or only latest. Useful when:
- A contract was deployed at a known block
- You only need data from a certain date forward
- You want to avoid processing irrelevant ancient blocks

**Combine source filtering with transform filtering:**
- Source `filter:` → coarse pre-filtering (contract addresses, block ranges)
- Transform `WHERE` → fine-grained filtering (event types, parameter values, exclusions)

---

## Debugging Transforms

### Common Errors

**"Unknown source reference"**
The `FROM` clause references a name that doesn't match any source or transform key in the YAML. Check for typos.

**"Missing primary_key"**
Every transform needs `primary_key`. Almost always use `id` (carried from the source data).

**"Column not found"**
Column name doesn't exist on the source. Use `goldsky turbo inspect <pipeline> -n <source_node>` to see actual column names.

**Empty results from decoded events**
- Verify the ABI JSON matches the actual contract events
- Check `decoded.event_signature` matches the event name exactly (case-sensitive)
- Ensure `address` filter matches the correct contract
- Check `decoded.event_params[N]` indexing — parameters are **1-indexed**

**Type mismatch in UNION ALL**
All branches of a UNION ALL must have identical column counts and compatible types. Add placeholder columns (`''`, `0`) where needed.

### Inspecting Transform Output

Use the TUI inspector to see data at any node in the pipeline:

```bash
# Inspect a specific transform's output
goldsky turbo inspect <pipeline-name> -n <transform_name>
```

This helps verify that decoded fields, casts, and filters are producing expected results.

---

## Complete Example: Multi-Event Activity Feed

This end-to-end example shows how to build a unified activity feed from raw logs. See the template file `templates/multi-event-activity-feed.yaml` for the full working YAML.

**Pattern:**
1. Source raw logs filtered by contract addresses
2. Decode all events with `_gs_log_decode()`
3. Create individual transforms per event type, each mapping to a common schema
4. Combine with `UNION ALL`
5. Sink to a database

---

## Sink Batching Configuration

Database and streaming sinks support batching to tune latency vs throughput:

```yaml
sinks:
  my_sink:
    type: clickhouse
    from: my_transform
    table: my_table
    secret_name: MY_SECRET
    primary_key: id
    batch_size: 1000           # rows per batch
    batch_flush_interval: 300ms # max time before flushing
```

| Setting                | Description                              | Trade-off                        |
| ---------------------- | ---------------------------------------- | -------------------------------- |
| `batch_size`           | Max rows accumulated before flushing     | Higher = more throughput         |
| `batch_flush_interval` | Max wait time before flushing a batch    | Lower = lower latency            |

**Guidelines:**
- Latency-sensitive (real-time dashboards): `batch_flush_interval: 300ms`, `batch_size: 1000`
- Moderate throughput (trade data, events): `batch_flush_interval: 1000ms`, `batch_size: 1000`
- High-volume streaming (balance snapshots): `batch_flush_interval: 10s`, `batch_size: 100000`

---

## TypeScript / WASM Script Transforms

For logic that SQL can't express (complex conditionals, stateful processing, custom serialization, external data enrichment patterns), use `type: script` transforms.

### Basic Structure

```yaml
transforms:
  custom_logic:
    type: script
    primary_key: id
    language: typescript
    from: my_source
    schema:
      id: string
      block_number: uint64
      sender: string
      amount: string
      label: string
    script: |
      function transform(input) {
        // Return null to filter out a record
        if (input.amount === '0') return null;

        return {
          id: input.id,
          block_number: input.block_number,
          sender: input.sender,
          amount: input.amount,
          label: categorize(input.amount)
        };
      }

      function categorize(amount) {
        const val = BigInt(amount);
        if (val > BigInt('1000000000000000000000')) return 'whale';
        if (val > BigInt('1000000000000000000')) return 'large';
        return 'small';
      }
```

### Required Fields

| Field        | Required | Description                                              |
| ------------ | -------- | -------------------------------------------------------- |
| `type`       | Yes      | `script`                                                 |
| `primary_key`| Yes      | Column for uniqueness/ordering                           |
| `language`   | Yes      | `typescript` (transpiled to JS, runs in WASM sandbox)    |
| `from`       | Yes      | Source or transform to read from                         |
| `schema`     | Yes      | Output schema — map of column names to types             |
| `script`     | Yes      | TypeScript code with a `transform(input)` function       |

### Schema Types

Supported types for the `schema` field:

| Type       | Description             |
| ---------- | ----------------------- |
| `string`   | Text / VARCHAR          |
| `uint64`   | Unsigned 64-bit integer |
| `int64`    | Signed 64-bit integer   |
| `float64`  | Double precision float  |
| `boolean`  | True/false              |
| `bytes`    | Binary data             |

### Script Rules

1. **Must export a `transform(input)` function** — called once per record
2. **Return `null` to filter out a record** — the record is dropped
3. **Return an object matching the `schema`** — all declared fields must be present
4. **No async/await** — execution is synchronous within the WASM sandbox
5. **No external imports** — no `require()` or `import` (sandboxed environment)
6. **No network access** — for HTTP enrichment, use `handler` transforms instead
7. **Helper functions are fine** — define them in the same script block

### When to Use Script vs SQL

| Use Case                              | Transform Type | Why                                      |
| ------------------------------------- | -------------- | ---------------------------------------- |
| Filter by column value                | `sql`          | Simple WHERE clause                      |
| Decode EVM/Solana events              | `sql`          | Built-in decode functions                |
| Complex string parsing/regex          | `script`       | SQL regex is limited                     |
| Conditional field generation          | `sql`          | CASE WHEN is sufficient                  |
| BigInt arithmetic with custom logic   | `script`       | Native BigInt support in TypeScript      |
| Multi-step business logic             | `script`       | Readable imperative code                 |
| JSON construction/manipulation        | Either         | SQL `json_object()` or TS object literals|
| Stateful counters or accumulators     | `script`       | Not possible in streaming SQL            |

### Example — Categorize and Enrich Transfers

```yaml
transforms:
  enriched:
    type: script
    primary_key: id
    language: typescript
    from: erc20_transfers
    schema:
      id: string
      block_number: uint64
      sender: string
      recipient: string
      token_address: string
      amount_raw: string
      amount_human: string
      transfer_size: string
    script: |
      const KNOWN_TOKENS: Record<string, { symbol: string; decimals: number }> = {
        '0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48': { symbol: 'USDC', decimals: 6 },
        '0xdac17f958d2ee523a2206206994597c13d831ec7': { symbol: 'USDT', decimals: 6 },
        '0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2': { symbol: 'WETH', decimals: 18 },
      };

      function transform(input: any) {
        const addr = input.address?.toLowerCase() ?? '';
        const token = KNOWN_TOKENS[addr];
        const raw = BigInt(input.amount || '0');

        let amountHuman = input.amount;
        if (token) {
          const divisor = BigInt(10 ** token.decimals);
          amountHuman = (Number(raw) / Number(divisor)).toFixed(4);
        }

        return {
          id: input.id,
          block_number: input.block_number,
          sender: input.sender,
          recipient: input.recipient,
          token_address: addr,
          amount_raw: input.amount,
          amount_human: amountHuman,
          transfer_size: classifySize(raw),
        };
      }

      function classifySize(amount: bigint): string {
        if (amount === BigInt(0)) return 'zero';
        if (amount < BigInt('1000000')) return 'dust';
        if (amount < BigInt('1000000000000000000')) return 'small';
        if (amount < BigInt('1000000000000000000000')) return 'medium';
        return 'whale';
      }
```

### Chaining Script + SQL Transforms

You can chain script transforms with SQL transforms in either order:

```yaml
transforms:
  # Step 1: SQL decode
  decoded:
    type: sql
    primary_key: id
    sql: |
      SELECT _gs_log_decode('[...]', topics, data) AS decoded,
        id, block_number, transaction_hash, address
      FROM raw_logs

  # Step 2: TypeScript enrichment
  enriched:
    type: script
    primary_key: id
    language: typescript
    from: decoded
    schema:
      id: string
      block_number: uint64
      category: string
      risk_score: float64
    script: |
      function transform(input) {
        return {
          id: input.id,
          block_number: input.block_number,
          category: assessCategory(input),
          risk_score: computeRisk(input)
        };
      }
      // ... helper functions
```

---

## Dynamic Table Transforms

Dynamic tables are **updatable lookup tables** that can be used for joins, allowlists, blocklists, or any filter that needs to change without redeploying the pipeline.

### When to Use Dynamic Tables

- **Allowlists/Blocklists** — filter transfers by a list of tracked wallets
- **Lookup joins** — enrich data with metadata (e.g., token symbol, protocol name)
- **Dynamic filtering** — change which addresses or tokens to track at runtime
- **Feature flags** — enable/disable processing paths without pipeline restart

### Basic Configuration

```yaml
transforms:
  tracked_wallets:
    type: dynamic_table
    primary_key: address
    backend:
      type: postgres                # or: in_memory
      secret_name: MY_POSTGRES
      table: tracked_wallets        # existing table in your database
    columns:
      address: string
      label: string
```

### Backend Types

| Backend      | Persistence         | Use Case                                    |
| ------------ | ------------------- | ------------------------------------------- |
| `postgres`   | Durable (database)  | Shared across restarts, externally updatable |
| `in_memory`  | Ephemeral           | Auto-populated from SQL, fast lookups        |

### Auto-Populating with SQL

Populate a dynamic table from another source or transform using the `sql` field:

```yaml
transforms:
  whale_addresses:
    type: dynamic_table
    primary_key: address
    backend:
      type: in_memory
    columns:
      address: string
      total_volume: string
    sql: |
      SELECT address, SUM(CAST(amount AS DOUBLE)) AS total_volume
      FROM erc20_transfers
      GROUP BY address
      HAVING SUM(CAST(amount AS DOUBLE)) > 1000000
```

### Using Dynamic Tables in SQL Transforms

Use `dynamic_table_check()` to filter records against a dynamic table:

```yaml
transforms:
  # The dynamic table (lookup data)
  tracked_wallets:
    type: dynamic_table
    primary_key: address
    backend:
      type: postgres
      secret_name: MY_POSTGRES
      table: tracked_wallets
    columns:
      address: string
      label: string

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

### Updating Dynamic Tables at Runtime

**Postgres-backed tables** can be updated externally — just INSERT/UPDATE/DELETE rows in the backing PostgreSQL table. The pipeline picks up changes automatically without restart.

**REST API updates** (for in-memory tables) use the Goldsky API:

```bash
# Add an entry
curl -X POST https://api.goldsky.com/turbo/v1/pipelines/<name>/dynamic-tables/tracked_wallets \
  -H "Authorization: Bearer <token>" \
  -d '{"address": "0xabc...", "label": "whale"}'

# Remove an entry
curl -X DELETE https://api.goldsky.com/turbo/v1/pipelines/<name>/dynamic-tables/tracked_wallets/0xabc...
```

### Full Example — Wallet Tracking Pipeline

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
    primary_key: address
    backend:
      type: postgres
      secret_name: TRACKING_DB
      table: tracked_wallets
    columns:
      address: string
      label: string

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

---

## Handler (External HTTP) Transforms

For enrichment via external APIs (price feeds, metadata lookups, off-chain data):

```yaml
transforms:
  enriched:
    type: handler
    primary_key: id
    from: my_source
    url: https://my-enrichment-api.example.com/process
    headers:
      Authorization: Bearer my-token
    batch_size: 100
    timeout_ms: 5000
```

### Handler Transform Fields

| Field        | Required | Description                                          |
| ------------ | -------- | ---------------------------------------------------- |
| `type`       | Yes      | `handler`                                            |
| `primary_key`| Yes      | Column for uniqueness                                |
| `from`       | Yes      | Source or transform to read from                     |
| `url`        | Yes      | HTTP endpoint that receives and returns data         |
| `headers`    | No       | HTTP headers for authentication                      |
| `batch_size` | No       | Records per HTTP request (default varies)            |
| `timeout_ms` | No       | Request timeout in milliseconds                      |

Your HTTP endpoint receives a JSON array of records and must return a JSON array of the same length with enriched records. Any language/framework works for the handler.

---

## Solana Transform Patterns

### Decoding Solana Instructions with IDL

Use `_gs_decode_instruction_data()` with a program's IDL to decode instruction data:

```yaml
transforms:
  decoded_instructions:
    type: sql
    primary_key: id
    sql: |
      SELECT
        id,
        block_number,
        _gs_decode_instruction_data(
          '{"version":"0.1.0","name":"my_program","instructions":[...]}',
          instruction_data
        ) AS decoded,
        transaction_hash
      FROM solana_instructions
      WHERE program_id = 'TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA'
```

The returned struct has `decoded.name` (instruction name) and `decoded.value` (decoded parameters).

### Decoding Solana Logs

```sql
_gs_decode_log_message(
  '{"version":"0.1.0","name":"my_program","events":[...]}',
  log_messages
) AS decoded_log
```

### Program-Specific Decoders (No IDL Needed)

These built-in decoders handle common Solana programs without requiring an IDL:

```sql
-- SPL Token Program (transfers, mints, burns)
gs_solana_decode_token_program_instruction(instruction_data)

-- System Program (SOL transfers, account creation)
gs_solana_decode_system_program_instruction(instruction_data)

-- Associated Token Account Program
gs_solana_decode_associated_token_program_instruction(instruction_data)

-- Stake Program
gs_solana_decode_stake_program_instruction(instruction_data)

-- Vote Program
gs_solana_decode_vote_program_instruction(instruction_data)

-- Extract accounts from transaction data
gs_solana_get_accounts(transaction_data)

-- Extract balance changes
gs_solana_get_balance_changes(transaction_data)
```

### Example — Track SPL Token Transfers on Solana

```yaml
name: solana-spl-tracker
resource_size: s

sources:
  sol_txns:
    type: dataset
    dataset_name: solana.transactions_with_instructions
    version: 1.0.0
    start_at: latest

transforms:
  token_instructions:
    type: sql
    primary_key: id
    sql: |
      SELECT
        id,
        block_number,
        transaction_hash,
        gs_solana_decode_token_program_instruction(instruction_data) AS decoded
      FROM sol_txns
      WHERE program_id = 'TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA'

  transfers_only:
    type: sql
    primary_key: id
    sql: |
      SELECT
        id,
        block_number,
        transaction_hash,
        decoded.name AS instruction_type,
        decoded.value AS params
      FROM token_instructions
      WHERE decoded.name = 'Transfer'

sinks:
  output:
    type: blackhole
    from: transfers_only
```

### Base58 Decoding

Convert Solana base58-encoded data to binary:

```sql
_gs_from_base58('3Bxs3zy...')  -- returns BINARY
```

---

## Function Examples

### Array Function Patterns

```sql
-- Filter an array of structs by a field value
SELECT array_filter(instructions, 'program_id', 'TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA')
  AS token_instructions
FROM solana_transactions

-- Get just the first matching element
SELECT array_filter_first(instructions, 'program_id', 'Vote111111111111111111111111111111111111111')
  AS vote_instruction
FROM solana_transactions

-- Filter by multiple values (prevents overflow on large arrays)
SELECT array_filter_in(instructions, 'program_id', ARRAY[
  'TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA',
  '11111111111111111111111111111111'
]) AS filtered
FROM solana_transactions

-- Add index to each element for position tracking
SELECT array_enumerate(log_messages) AS indexed_logs
FROM solana_transactions
-- Each element becomes {index: N, value: original_element}

-- Combine parallel arrays element-wise
SELECT zip_arrays(keys, values) AS key_value_pairs
FROM my_data
-- Combines into [{keys[0], values[0]}, {keys[1], values[1]}, ...]

-- Convert to large-list for arrays with >2B elements
SELECT to_large_list(massive_array) AS big_list
FROM huge_dataset
```

### JSON Function Patterns

```sql
-- Query nested JSON
SELECT json_query('{"user":{"name":"Alice","age":30}}', '$.user.name')
-- Returns: "Alice"

-- Extract scalar value
SELECT json_value('{"price":"19.99","currency":"USD"}', '$.price')
-- Returns: 19.99

-- Check if path exists
SELECT json_exists('{"data":{"nested":true}}', '$.data.nested')
-- Returns: true

-- Construct JSON objects for webhook payloads
SELECT json_object(
  'event_type', 'transfer',
  'from', sender,
  'to', recipient,
  'amount', amount
) AS payload
FROM transfers

-- Construct JSON arrays
SELECT json_array(sender, recipient, amount) AS participants
FROM transfers

-- Safe parsing (returns NULL instead of error)
SELECT try_parse_json(maybe_json_column) AS parsed
FROM my_data
WHERE is_json(maybe_json_column)
```

### Hex and Encoding Patterns

```sql
-- Convert hex string to binary
SELECT _gs_hex_to_byte('0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef')
  AS topic_bytes

-- Convert binary back to hex
SELECT _gs_byte_to_hex(some_binary_column) AS hex_string

-- Split strings into arrays
SELECT string_to_array('0xabc,0xdef,0x123', ',') AS addresses

-- Regex extraction
SELECT regexp_extract(input_data, '0x([a-f0-9]{8})', 1) AS function_selector

-- Regex replacement
SELECT regexp_replace(address, '^0x', '') AS clean_address
```

---

## Related Skills

- **`/turbo-pipelines`** — Full pipeline creation, deployment, and configuration
- **`/turbo-architecture`** — Pipeline architecture decisions (source types, data flow patterns, resource sizing, dynamic tables)
- **`/goldsky-datasets`** — Discover available datasets and their schemas
- **`/turbo-monitor-debug`** — Inspect transform output and debug pipeline issues
