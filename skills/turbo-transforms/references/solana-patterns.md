# Solana Transform Patterns & Function Examples

## Solana Transform Patterns

### How Solana decoding works (read this first)

A Solana instruction has three parts:

- `program_id` — the program that runs
- `accounts` — the account public keys the instruction touches (an array)
- `data` — an **opaque byte array**: an instruction selector followed by its arguments

In Goldsky's Solana datasets the instruction bytes live in a column literally named **`data`** (not `instruction_data`), and its value is a **base58 string**. That base58 is only the *transport encoding of the raw bytes* — it is **not** decoded meaning.

> **⚠️ base58 is not decoding.** Base58-decoding `data` yourself only turns the string back into raw bytes; it does **not** give you the instruction name or parameters. There is no universal instruction layout on Solana — each program defines its own — so you must decode with something that knows the program's schema. Do **not** try to decode instructions with `_gs_from_base58`. Pass the base58 `data` column *directly* to one of the decoders below; they base58-decode, read the selector, and deserialize internally.

**Pick your decoder by `program_id`:**

| Program type | Decoder | Needs an IDL? |
| --- | --- | --- |
| Native / SPL (Token, System, Stake, Vote, Associated Token, BPF Loader, Address Lookup Table) | `_gs_solana_decode_<program>_instruction(data, accounts)` | No — layouts are built in |
| Any custom program (DEX, DeFi, NFT — Jupiter, Raydium, Drift, …) | `_gs_decode_instruction_data(idl, data)` | Yes — fetch with `_gs_fetch_abi(url, 'raw')` |

Custom (Anchor) programs identify each instruction by an 8-byte discriminator and Borsh-encode the arguments; the IDL is the schema that maps those bytes to names and values.

> **Solana column names.** Solana rows use `block_slot`, `block_timestamp`, and `signature` — **not** `block_number` or `transaction_hash`. The per-instruction dataset is `solana.instructions` (columns include `id`, `program_id`, `data`, `accounts`, `block_slot`, `signature`).

> **⚠️ Never fabricate program IDs or token mints.** The `program_id` / mint addresses in `filter:` and `WHERE program_id = '…'` are base58 Solana addresses — get them from the user, or look them up (e.g. a token mint via a token API); **never emit one from memory.** A guessed address is silently wrong: the pipeline validates and deploys fine but matches nothing (or the wrong program). If you don't have a verified address, ask the user to paste it rather than inventing one.

### Decoding custom programs with an IDL

Use `_gs_decode_instruction_data(idl, data)`. Fetch the IDL from a URL with `_gs_fetch_abi` (pass it inline for very small IDLs):

```yaml
transforms:
  decoded_instructions:
    type: sql
    primary_key: id
    sql: |
      SELECT
        id,
        program_id,
        _gs_decode_instruction_data(
          _gs_fetch_abi('https://example.com/raydium-idl.json', 'raw'),
          data
        ) AS decoded,
        accounts,
        block_slot,
        signature
      FROM solana_instructions
      WHERE program_id = 'CPMMoo8L3F4NbTegBCKVNunggL7H1ZpdTHKxQB5qKP1C'
```

The returned struct has `decoded.name` (instruction/event name) and `decoded.value` (a JSON string of the parameters — extract fields with `json_value(decoded.value, '$.amountIn')`). The function attempts instruction decoding first and falls back to event decoding.

### Decoding Solana logs

```sql
_gs_decode_log_message(
  _gs_fetch_abi('https://example.com/program-idl.json', 'raw'),
  log_messages
) AS decoded_log
```

Works best with Anchor programs that emit structured events. The IDL must match the deployed program version.

### Program-specific decoders (no IDL needed)

Built-in decoders for common native/SPL programs. **Every one takes `(data, accounts)`** and returns a struct with `.name` and `.value`:

```sql
_gs_solana_decode_token_program_instruction(data, accounts)             -- SPL Token: transfers, mints, burns
_gs_solana_decode_system_program_instruction(data, accounts)            -- System: SOL transfers, account creation
_gs_solana_decode_associated_token_program_instruction(data, accounts)  -- Associated Token Account
_gs_solana_decode_stake_program_instruction(data, accounts)             -- Stake
_gs_solana_decode_vote_program_instruction(data, accounts)              -- Vote
_gs_solana_decode_bpf_loader_instruction(data, accounts)                -- BPF loader
_gs_solana_decode_bpf_upgradeable_loader_instruction(data, accounts)    -- Upgradeable programs
_gs_solana_decode_address_lookup_table_instruction(data, accounts)      -- Address lookup tables
```

For unified account lists and SOL balance changes, see `_gs_solana_get_accounts(...)` and `_gs_solana_get_balance_changes(...)` in the [SQL functions reference](https://docs.goldsky.com/turbo-pipelines/reference/sql-functions#solana-functions).

### Example — Track SPL token transfers on Solana

```yaml
name: solana-spl-tracker
resource_size: s

sources:
  solana_ix:
    type: dataset
    dataset_name: solana.instructions
    version: 1.0.0
    # omit start_block to start from the latest slot

transforms:
  decoded_token_ops:
    type: sql
    primary_key: id
    sql: |
      SELECT
        id,
        block_slot,
        signature,
        _gs_solana_decode_token_program_instruction(data, accounts) AS decoded
      FROM solana_ix
      WHERE program_id = 'TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA'

  transfers_only:
    type: sql
    primary_key: id
    sql: |
      SELECT
        id,
        block_slot,
        signature,
        decoded.name AS instruction_type,
        decoded.value AS params
      FROM decoded_token_ops
      WHERE decoded.name = 'Transfer'

sinks:
  output:
    type: blackhole
    from: transfers_only
```

### `_gs_from_base58` — raw bytes only, NOT instruction decoding

`_gs_from_base58` converts a base58 string to its raw binary bytes. Use it for low-level byte work on addresses or signatures — **never** as a way to decode instruction `data`. To decode an instruction, use an IDL (`_gs_decode_instruction_data`) or a program-specific decoder (above).

```sql
_gs_from_base58('3Bxs3zy...')  -- returns BINARY (raw bytes, NOT a decoded instruction)
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
