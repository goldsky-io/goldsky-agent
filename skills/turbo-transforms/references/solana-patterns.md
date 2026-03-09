# Solana Transform Patterns & Function Examples

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
