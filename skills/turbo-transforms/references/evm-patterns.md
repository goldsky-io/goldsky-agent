# EVM Transform Patterns

Advanced patterns for decoding and processing EVM blockchain data in Turbo pipelines.

## Table of Contents

1. [Decode Once, Filter Many](#decode-once-filter-many)
2. [Transform Chaining](#transform-chaining)
3. [UNION ALL — Combining Multiple Event Types](#union-all--combining-multiple-event-types)
4. [Normalizing Disparate Events to a Common Schema](#normalizing-disparate-events-to-a-common-schema)
5. [Adding Columns to an Existing Transform](#adding-columns-to-an-existing-transform)

---

## Decode Once, Filter Many

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

---

## Transform Chaining

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

---

## UNION ALL — Combining Multiple Event Types

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

---

## Normalizing Disparate Events to a Common Schema

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

---

## Adding Columns to an Existing Transform

Extend a transform's output without rewriting it:

```yaml
  activities_v2:
    type: sql
    primary_key: id
    sql: SELECT *, '' AS builder FROM all_activities
```
