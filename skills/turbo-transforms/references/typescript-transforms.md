# TypeScript / WASM Script Transforms & Handler Transforms

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
