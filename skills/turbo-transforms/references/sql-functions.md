# SQL Function Reference

Complete reference for all Goldsky-specific SQL functions available in Turbo pipeline transforms.

## Table of Contents

1. [EVM Log Decoding](#evm-log-decoding)
2. [EVM Transaction Decoding](#evm-transaction-decoding)
3. [ABI Fetching](#abi-fetching)
4. [Hashing Functions](#hashing-functions)
5. [U256/I256 Integer Math](#u256i256-integer-math)
6. [Solana Decode Functions](#solana-decode-functions)
7. [Array Functions](#array-functions)
8. [JSON Functions](#json-functions)
9. [Time Functions](#time-functions)
10. [Dynamic Table Check](#dynamic-table-check)
11. [String and Encoding Functions](#string-and-encoding-functions)
12. [Standard SQL Functions](#standard-sql-functions)

---

## EVM Log Decoding

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

---

## ABI Fetching

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

---

## Hashing Functions

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

---

## U256/I256 Integer Math

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

---

## Solana Decode Functions

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

For full Solana patterns and examples, see `solana-patterns.md`.

---

## Array Functions

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

---

## JSON Functions

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

---

## Time Functions

```sql
to_timestamp(seconds) -> TIMESTAMP
to_timestamp_micros(microseconds) -> TIMESTAMP
now() -> TIMESTAMP                              -- volatile, current time
date_part('hour', timestamp) -> INT             -- extract timestamp parts
```

---

## Dynamic Table Check

Check if a value exists in a dynamic table (async). Used with `dynamic_table` transforms.

```sql
WHERE dynamic_table_check('tracked_wallets', from_address)
```

---

## String and Encoding Functions

```sql
_gs_hex_to_byte(hex_string) -> BINARY
_gs_byte_to_hex(bytes) -> VARCHAR
string_to_array(string, delimiter) -> LIST<VARCHAR>
regexp_extract(string, pattern, group_index) -> VARCHAR
regexp_replace(string, pattern, replacement) -> VARCHAR
```

---

## Standard SQL Functions

All Apache DataFusion SQL functions are also available: `lower`, `upper`, `trim`, `substring`, `concat`, `replace`, `reverse`, `COALESCE`, `CASE WHEN`, `CAST`, etc.

```sql
-- Common patterns
lower('0xABC...')                              -- case-insensitive address
CONCAT('base', '-', COALESCE(addr, ''))        -- composite keys
COALESCE(balance.contract_address, '')         -- null-safe values
to_timestamp(block_timestamp) AS block_time    -- timestamp conversion
```
