---
name: turbo-pipelines
description: "YAML configuration reference for Turbo pipelines — sources, transforms, sinks, and troubleshooting. Use when looking up specific fields or syntax. For interactive pipeline building, use @pipeline-builder instead."
---

# Turbo Pipeline Configuration Reference

YAML configuration reference for Turbo pipelines. This is a lookup reference — for interactive pipeline building, use `@pipeline-builder`. For pipeline troubleshooting, use `@pipeline-doctor`.

> **CRITICAL:** Always validate YAML with `goldsky turbo validate <file.yaml>` before deploying.

---

## Quick Start

Deploy a minimal pipeline:

```yaml
name: my-first-pipeline
resource_size: s
sources:
  transfers:
    type: dataset
    dataset_name: base.erc20_transfers
    version: 1.2.0
    start_at: latest
transforms: {}
sinks:
  output:
    type: blackhole
    from: transfers
```

```bash
goldsky turbo apply pipeline.yaml -i
```

---

## Prerequisites

- [ ] **Goldsky CLI installed** - `curl https://goldsky.com | sh`
- [ ] **Turbo CLI extension installed** (SEPARATE binary!) - `curl https://install-turbo.goldsky.com | sh`
  - Note: Run `goldsky turbo list` - if you see "The turbo binary is not installed", install it first
- [ ] **Logged in** - `goldsky login`
- [ ] Pipeline YAML file ready
- [ ] Secrets created for sinks (if using PostgreSQL, ClickHouse, Kafka, etc.)

## Discovering Available Data Sources

**For dataset discovery, invoke the `goldsky-datasets` skill.**

Quick reference for common datasets:

| What They Want             | Dataset to Use             |
| -------------------------- | -------------------------- |
| Token transfers (fungible) | `<chain>.erc20_transfers`  |
| NFT transfers              | `<chain>.erc721_transfers` |
| All contract events        | `<chain>.logs`             |
| Block data                 | `<chain>.blocks`           |
| Transaction data           | `<chain>.transactions`     |

For full chain prefixes, dataset types, and version discovery, use `/goldsky-datasets`.

---

## Quick Reference

### Installation Commands

| Action                  | Command                                        |
| ----------------------- | ---------------------------------------------- |
| Install Goldsky CLI     | `curl https://goldsky.com \| sh`               |
| Install Turbo extension | `curl https://install-turbo.goldsky.com \| sh` |
| Verify Turbo installed  | `goldsky turbo list`                           |

### Pipeline Commands

| Action                  | Command                                                |
| ----------------------- | ------------------------------------------------------ |
| List datasets           | `goldsky dataset list` ⚠️ **Slow (30-60s)**            |
| **Validate (REQUIRED)** | `goldsky turbo validate pipeline.yaml` ✓ **Fast (3s)** |
| Deploy/Update           | `goldsky turbo apply pipeline.yaml`                    |
| Deploy + Inspect        | `goldsky turbo apply pipeline.yaml -i`                 |
| List pipelines          | `goldsky turbo list`                                   |
| View live data          | `goldsky turbo inspect <name>`                         |
| Inspect node            | `goldsky turbo inspect <name> -n <node>`               |
| View logs               | `goldsky turbo logs <name>`                            |
| Follow logs             | `goldsky turbo logs <name> --follow`                   |
| Pause                   | `goldsky turbo pause <name>`                           |
| Resume                  | `goldsky turbo resume <name>`                          |
| Restart                 | `goldsky turbo restart <name>`                         |
| Restart (clear state)   | `goldsky turbo restart <name> --clear-state`           |
| Delete                  | `goldsky turbo delete <name>`                          |
| List secrets            | `goldsky secret list`                                  |

---

## Configuration Reference

### Pipeline Structure

Every Turbo pipeline YAML has this structure:

```yaml
name: my-pipeline # Required: unique identifier
resource_size: s # Required: s, m, or l
description: "Optional desc" # Optional: what the pipeline does

sources:
  source_name: # Define data inputs
    type: dataset
    # ... source config

transforms: # Optional: process data
  transform_name:
    type: sql
    # ... transform config

sinks:
  sink_name: # Define data outputs
    type: postgres
    # ... sink config
```

### Top-Level Fields

| Field           | Required | Description                                     |
| --------------- | -------- | ----------------------------------------------- |
| `name`          | Yes      | Unique pipeline identifier (lowercase, hyphens)                  |
| `resource_size` | Yes      | Worker allocation: `s`, `m`, or `l`                              |
| `description`   | No       | Human-readable description                                       |
| `job`           | No       | `true` for one-time batch jobs (default: `false` = streaming)    |
| `sources`       | Yes      | Data input definitions                                           |
| `transforms`    | No       | Data processing definitions                                      |
| `sinks`         | Yes      | Data output definitions                                          |

### Job Mode

Set `job: true` for one-time batch processing (historical backfills, data exports):

```yaml
name: backfill-usdc-history
resource_size: l
job: true

sources:
  logs:
    type: dataset
    dataset_name: ethereum.raw_logs
    version: 1.0.0
    start_at: earliest
    end_block: 19000000
    filter: >-
      address = '0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48'
transforms: {}
sinks:
  output:
    type: s3_sink
    from: logs
    endpoint: https://s3.amazonaws.com
    bucket: my-backfill-bucket
    prefix: usdc/
    secret_name: MY_S3
```

**Job mode rules:**
- Runs to completion and auto-cleans up ~1 hour after finishing
- **Must `goldsky turbo delete` before redeploying** — cannot update in-place
- **Cannot use `restart`** — use delete + apply instead
- Use `end_block` to bound the range (otherwise processes to chain tip and stops)
- Best with `resource_size: l` for faster backfills

> **For architecture guidance on when to use job vs streaming mode, see `/turbo-architecture`.**

### Resource Sizes

| Size | Workers | Use Case                           |
| ---- | ------- | ---------------------------------- |
| `s`  | 1       | Testing, low-volume data           |
| `m`  | 2       | Production, moderate volume        |
| `l`  | 4       | High-volume, multi-chain pipelines |

---

## Source Configuration

### Dataset Source

```yaml
sources:
  my_source:
    type: dataset
    dataset_name: <chain>.<dataset_type>
    version: <version>
    start_at: latest | earliest # EVM chains
    # OR
    start_block: <slot_number> # Solana only
```

### Source Fields

| Field          | Required | Description                                              |
| -------------- | -------- | -------------------------------------------------------- |
| `type`         | Yes      | `dataset` for blockchain data                            |
| `dataset_name` | Yes      | Format: `<chain>.<dataset_type>`                         |
| `version`      | Yes      | Dataset version (e.g., `1.2.0`)                          |
| `start_at`     | EVM      | `latest` or `earliest`                                   |
| `start_block`  | Solana   | Specific slot number (omit for latest)                   |
| `end_block`    | No       | Stop processing at this block (for bounded backfills)    |
| `filter`       | No       | SQL WHERE clause to pre-filter at source level (efficient)|

### Source-Level Filtering

Use `filter` to reduce data volume **before** it reaches transforms. This is significantly more efficient than filtering in SQL transforms because it eliminates data at the ingestion layer:

```yaml
sources:
  usdc_logs:
    type: dataset
    dataset_name: base.raw_logs
    version: 1.0.0
    start_at: earliest
    filter: >-
      address = lower('0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913')
      AND block_number >= 10000000
```

**Best practices:**
- Use `filter` for contract addresses and block ranges (coarse pre-filtering)
- Use transform `WHERE` for event types, parameter values, exclusions (fine-grained)
- `filter` uses standard SQL WHERE syntax (same as DataFusion)
- Combine `filter` with `start_at: earliest` + `end_block` for precise bounded backfills

### Available Chains

**EVM Chains:**

| Chain Prefix | Network           |
| ------------ | ----------------- |
| `ethereum`   | Ethereum Mainnet  |
| `base`       | Base              |
| `matic`      | Polygon           |
| `arbitrum`   | Arbitrum One      |
| `optimism`   | Optimism          |
| `bsc`        | BNB Smart Chain   |
| `avalanche`  | Avalanche C-Chain |

**Non-EVM Chains:**

| Chain Prefix        | Network   | Note                                |
| ------------------- | --------- | ----------------------------------- |
| `solana`            | Solana    | Uses `start_block` not `start_at`   |
| `bitcoin.raw`       | Bitcoin   | Uses `start_at` like EVM            |
| `stellar_mainnet`   | Stellar   | Uses `start_at` like EVM, v1.1.0    |
| `sui`               | Sui       | Uses `start_at` like EVM            |
| `near`              | NEAR      | Uses `start_at` like EVM            |
| `starknet`          | Starknet  | Uses `start_at` like EVM            |
| `fogo`              | Fogo      | Uses `start_at` like EVM            |

### Common Dataset Types

**EVM:**

| Dataset Type            | Description                               |
| ----------------------- | ----------------------------------------- |
| `blocks`                | Block headers                             |
| `raw_transactions`      | Transaction data (**NOT** `transactions`) |
| `raw_logs`              | Event logs                                |
| `raw_traces`            | Internal transaction traces               |
| `erc20_transfers`       | ERC-20 token transfers                    |
| `erc721_transfers`      | ERC-721 NFT transfers                     |
| `erc1155_transfers`     | ERC-1155 multi-token transfers            |
| `decoded_logs`          | ABI-decoded event logs                    |

**Solana:** `blocks`, `transactions`, `transactions_with_instructions`, `instructions`, `token_transfers`, `native_balances`, `token_balances`, `rewards`

**Bitcoin:** `bitcoin.raw.blocks`, `bitcoin.raw.transactions`

**Stellar:** `stellar_mainnet.transactions`, `stellar_mainnet.transfers`, `stellar_mainnet.events`, `stellar_mainnet.operations`, `stellar_mainnet.ledger_entries`, `stellar_mainnet.ledgers`, `stellar_mainnet.balances`

**Sui:** `sui.checkpoints`, `sui.transactions`, `sui.events`, `sui.packages`, `sui.epochs`

**NEAR:** `near.receipts`, `near.transactions`, `near.execution_outcomes`

**Starknet:** `starknet.blocks`, `starknet.transactions`, `starknet.events`, `starknet.messages`

**Fogo:** `fogo.transactions_with_instructions`, `fogo.rewards`, `fogo.blocks`

---

## Transform Configuration

### Transform Types

| Type            | Use Case                              |
| --------------- | ------------------------------------- |
| `sql`           | Filtering, projections, SQL functions |
| `script`        | Custom TypeScript/WASM logic          |
| `handler`       | Call external HTTP APIs to enrich data|
| `dynamic_table` | Lookup tables backed by a database    |

### SQL Transform

Most common transform type:

```yaml
transforms:
  filtered:
    type: sql
    primary_key: id
    sql: |
      SELECT
        id,
        sender,
        recipient,
        amount
      FROM source_name
      WHERE amount > 1000
```

| Field         | Required | Description                            |
| ------------- | -------- | -------------------------------------- |
| `type`        | Yes      | `sql`                                  |
| `primary_key` | Yes      | Column for uniqueness/ordering         |
| `sql`         | Yes      | SQL query (reference sources by name)  |
| `from`        | No       | Override default source (for chaining) |

### TypeScript Transform

For complex logic that SQL can't handle (runs in WASM sandbox):

```yaml
transforms:
  custom:
    type: script
    primary_key: id
    language: typescript
    from: source_name
    schema:
      id: string
      sender: string
      amount: string
      processed_at: string
    script: |
      function transform(input) {
        if (input.amount < 1000) return null;  // Filter out
        return {
          id: input.id,
          sender: input.sender,
          amount: input.amount,
          processed_at: new Date().toISOString()
        };
      }
```

> **For full TypeScript transform documentation, schema types, and examples, see `/turbo-transforms`.**

### Dynamic Table Transform

Updatable lookup tables for runtime filtering (allowlists, blocklists, enrichment):

```yaml
transforms:
  tracked_wallets:
    type: dynamic_table
    primary_key: address
    backend:
      type: postgres        # or: in_memory
      secret_name: MY_DB
      table: tracked_wallets
    columns:
      address: string
      label: string
```

Use with `dynamic_table_check()` in SQL transforms:

```sql
WHERE dynamic_table_check('tracked_wallets', sender)
```

> **For full dynamic table documentation, backend options, and examples, see `/turbo-transforms`.**

### Handler Transform

Call external HTTP APIs to enrich data:

```yaml
transforms:
  enriched:
    type: handler
    primary_key: id
    from: my_source
    url: https://my-api.example.com/enrich
    headers:
      Authorization: Bearer my-token
    batch_size: 100
    timeout_ms: 5000
```

> **For full handler transform documentation, see `/turbo-transforms`.**

### Transform Chaining

Chain transforms using `from`:

```yaml
transforms:
  step1:
    type: sql
    primary_key: id
    sql: SELECT * FROM source WHERE amount > 100

  step2:
    type: sql
    primary_key: id
    from: step1
    sql: SELECT *, 'processed' as status FROM step1
```

---

## Sink Configuration

### Common Sink Fields

| Field         | Required | Description                         |
| ------------- | -------- | ----------------------------------- |
| `type`        | Yes      | Sink type                           |
| `from`        | Yes      | Source or transform to read from    |
| `secret_name` | Varies   | Secret for credentials (most sinks) |
| `primary_key` | Varies   | Column for upserts (database sinks) |

### Blackhole Sink (Testing)

```yaml
sinks:
  test_output:
    type: blackhole
    from: my_transform
```

### PostgreSQL Sink

```yaml
sinks:
  postgres_output:
    type: postgres
    from: my_transform
    schema: public
    table: my_table
    secret_name: MY_POSTGRES_SECRET
    primary_key: id
```

**Secret format:** PostgreSQL connection string:
```
postgres://username:password@host:port/database
```

### PostgreSQL Aggregate Sink

Real-time aggregations in PostgreSQL using database triggers. Data flows into a landing table, and a trigger maintains aggregated values in a separate table.

```yaml
sinks:
  balances:
    type: postgres_aggregate
    from: transfers
    schema: public
    landing_table: transfer_log
    agg_table: account_balances
    primary_key: transfer_id
    secret_name: MY_POSTGRES
    group_by:
      account:
        type: text
    aggregate:
      balance:
        from: amount
        fn: sum
```

Supported aggregation functions: `sum`, `count`, `avg`, `min`, `max`

### ClickHouse Sink

```yaml
sinks:
  clickhouse_output:
    type: clickhouse
    from: my_transform
    table: my_table
    secret_name: MY_CLICKHOUSE_SECRET
    primary_key: id
```

**Secret format:** ClickHouse connection string:
```
https://username:password@host:port/database
```

### Kafka Sink

```yaml
sinks:
  kafka_output:
    type: kafka
    from: my_transform
    topic: my-topic
    topic_partitions: 10
    data_format: avro          # or: json
    schema_registry_url: http://schema-registry:8081  # required for avro
```

### Webhook Sink

> **Note:** Turbo webhook sinks do **not** support Goldsky's native secrets management. Include auth headers directly in the pipeline config.

```yaml
sinks:
  webhook_output:
    type: webhook
    from: my_transform
    url: https://api.example.com/webhook
    one_row_per_request: true
    headers:
      Authorization: Bearer your-token
      Content-Type: application/json
```

### S3 Sink

```yaml
sinks:
  s3_output:
    type: s3_sink
    from: my_transform
    endpoint: https://s3.amazonaws.com
    bucket: my-bucket
    prefix: data/
    secret_name: MY_S3_SECRET
```

**Secret format:** `access_key_id:secret_access_key` (or `access_key_id:secret_access_key:session_token` for temporary credentials)

### S2 Sink

Publish to [S2.dev](https://s2.dev) streams — a serverless alternative to Kafka.

```yaml
sinks:
  s2_output:
    type: s2_sink
    from: my_transform
    access_token: your_access_token
    basin: your-basin-name
    stream: your-stream-name
```

---

## Starter Templates

> **Template files are available in the `templates/` folder.** Copy and customize these for your pipelines.

| Template                       | Description                       | Use Case                     |
| ------------------------------ | --------------------------------- | ---------------------------- |
| `minimal-erc20-blackhole.yaml` | Simplest pipeline, no credentials | Quick testing                |
| `filtered-transfers-sql.yaml`  | Filter by contract address        | USDC, specific tokens        |
| `postgres-output.yaml`         | Write to PostgreSQL               | Production data storage      |
| `multi-chain-pipeline.yaml`    | Combine multiple chains           | Cross-chain analytics        |
| `solana-transfers.yaml`        | Solana SPL tokens                 | Non-EVM chains               |
| `multi-sink-pipeline.yaml`     | Multiple outputs                  | Archive + alerts + streaming |

**To use a template:**

```bash
# Copy template to your project
cp templates/minimal-erc20-blackhole.yaml my-pipeline.yaml

# Customize as needed, then validate
goldsky turbo validate my-pipeline.yaml

# Deploy
goldsky turbo apply my-pipeline.yaml -i
```

**Template location:** `templates/` (relative to this skill's directory)

---

## Common Update Patterns

### Adding a SQL Transform

**Before:**

```yaml
transforms: {}
sinks:
  output:
    type: blackhole
    from: transfers
```

**After:**

```yaml
transforms:
  filtered:
    type: sql
    primary_key: id
    sql: |
      SELECT * FROM transfers WHERE amount > 1000000
sinks:
  output:
    type: blackhole
    from: filtered # Changed from 'transfers'
```

### Adding a PostgreSQL Sink

```yaml
sinks:
  existing_sink:
    type: blackhole
    from: my_transform
  # Add new sink
  postgres_output:
    type: postgres
    from: my_transform
    schema: public
    table: my_data
    secret_name: MY_POSTGRES_SECRET
    primary_key: id
```

### Changing Resource Size

```yaml
resource_size: m # was: s
```

### Adding a New Source

```yaml
sources:
  eth_transfers:
    type: dataset
    dataset_name: ethereum.erc20_transfers
    version: 1.0.0
    start_at: latest
  # Add new source
  base_transfers:
    type: dataset
    dataset_name: base.erc20_transfers
    version: 1.2.0
    start_at: latest
```

---

## Checkpoint Behavior

### Understanding Checkpoints

When you update a pipeline:

- **Checkpoints are preserved by default** - Processing continues from where it left off
- **Source checkpoints are tied to source names** - Renaming a source resets its checkpoint
- **Pipeline checkpoints are tied to pipeline names** - Renaming the pipeline resets all checkpoints

### Resetting Checkpoints

**Option 1:** Rename the source

```yaml
sources:
  transfers_v2: # Changed from 'transfers'
    type: dataset
    dataset_name: base.erc20_transfers
    version: 1.2.0
    start_at: earliest # Will process from beginning
```

**Option 2:** Rename the pipeline

```yaml
name: my-pipeline-v2 # Changed from 'my-pipeline'
```

**Warning:** Resetting checkpoints means reprocessing all historical data.

---

## Troubleshooting

### CLI Hanging or Not Responding

If `goldsky` commands hang without producing output:

**Symptom:** Command runs but produces no output, cursor just sits there.

**Cause:** Often caused by the update notifier trying to check for updates and failing (network issues, DNS resolution, etc.)

**Solutions:**

1. **Disable update notifier:**

   ```bash
   GOLDSKY_NO_UPDATE_NOTIFIER=1 goldsky project list
   ```

2. **Set timeout for commands:**

   ```bash
   timeout 30 goldsky project list
   ```

3. **Check network connectivity:**

   ```bash
   curl -I https://goldsky.com
   ```

4. **If the goldsky CLI works but `turbo` commands hang:**

   The `turbo` binary may need to be reinstalled:

   ```bash
   # Remove existing turbo binary
   rm -f ~/.goldsky/bin/turbo

   # Reinstall
   curl https://install-turbo.goldsky.com | sh
   ```

### Turbo Binary Not Found

**Symptom:** `goldsky turbo list` shows "The turbo binary is not installed"

**Solution:**

```bash
curl https://install-turbo.goldsky.com | sh
```

Then verify:

```bash
goldsky turbo list
```

### Common Validation Errors

**Error: Unknown dataset**

```
Error: Source 'my_source' references unknown dataset 'invalid.dataset'
```

Fix: Use correct format `<chain>.<dataset_type>`. Use validation to test: `goldsky turbo validate pipeline.yaml`. Note: `raw_transactions` not `transactions`.

**Error: Missing primary_key**

```
Error: Transform 'my_transform' requires primary_key
```

Fix: Add `primary_key: id` (or appropriate column) to the transform.

**Error: Unknown source reference**

```
Error: Transform 'filtered' references unknown source 'wrong_name'
```

Fix: Check the `FROM` clause in SQL matches the source name exactly.

**Error: Secret not found**

```
Error: Secret 'MY_SECRET' not found
```

Fix: Create the secret first with `goldsky secret create --name MY_SECRET`.

**Error: Invalid YAML syntax**

```
Error: YAML parsing failed
```

Fix: Check indentation (use spaces, not tabs). Validate YAML syntax online.

**Error: Duplicate primary key**

```
Error: Duplicate primary key in transform 'my_transform'
```

Fix: Ensure your SQL produces unique values for the `primary_key` column.

### Common Runtime Errors (After Deployment)

These errors appear in `goldsky turbo logs <pipeline>` after deployment:

**Error: Password authentication failed**

```
Execution error: Failed to create PostgreSQL connection: error returned from database: password authentication failed for user 'username'
```

**Cause:** Secret has incorrect credentials.
**Fix:**

1. Verify credentials work: `psql 'postgresql://user:pass@host/db'`
2. Update the secret: `goldsky secret update SECRET_NAME --value '...'`
3. Redeploy: `goldsky turbo apply pipeline.yaml`

**Error: Project size limit exceeded (Neon free tier)**

```
Execution error: Failed to create table '...': error returned from database: could not extend file because project size limit (512 MB) has been exceeded
```

**Cause:** Neon free tier databases are limited to 512MB.
**Fix:**

1. Upgrade Neon plan, OR
2. Use a different database, OR
3. Clear existing data from the database

**Error: Connection refused**

```
Execution error: Failed to create PostgreSQL connection: Connection refused
```

**Cause:** Database is unreachable (firewall, wrong host, database down).
**Fix:**

1. Verify the host is correct
2. Check database is running
3. Ensure Goldsky IPs are allowed through firewall

**Error: SSL required**

```
Execution error: SSL connection is required
```

**Cause:** Database requires SSL but secret doesn't enable it.
**Fix:** Most managed PostgreSQL (Neon, Supabase) handle SSL automatically. If using self-hosted, configure SSL in your database.

### Quick Troubleshooting Table

| Issue                          | Action                                                            |
| ------------------------------ | ----------------------------------------------------------------- |
| **CLI hangs / no output**      | Run with `GOLDSKY_NO_UPDATE_NOTIFIER=1 goldsky <command>`         |
| **Turbo binary not installed** | Run `curl https://install-turbo.goldsky.com \| sh`                |
| **"turbo binary not found"**   | Same as above - Turbo is a separate binary that must be installed |
| Not logged in                  | Invoke `goldsky-auth-setup` skill                                 |
| Secret not found               | Invoke `goldsky-secrets` skill to create it                       |
| Dataset not found              | Use `raw_transactions` not `transactions`. Validate first         |
| Validation failed              | Review error message and fix YAML syntax                          |
| Pipeline name exists           | Use different name or delete existing pipeline                    |
| Permission denied              | Check you have Editor or Admin role                               |
| Transform not working          | Verify SQL syntax and column names                                |
| Sink not receiving data        | Check `from` field points to correct source/transform             |
| Data not flowing               | Check logs with `goldsky turbo logs <pipeline>`                   |
| Want to restart from scratch   | Rename the source or pipeline name                                |
| **Auth failed (runtime)**      | Update secret credentials, redeploy pipeline                      |
| **Storage limit exceeded**     | Neon free tier is 512MB - upgrade or use different DB             |

---

## Related

- **`@pipeline-builder`** - Interactive wizard to build pipelines step-by-step
- **`@pipeline-doctor`** - Diagnose and fix pipeline issues
- **`@dataset-finder`** - Quick dataset name lookup
