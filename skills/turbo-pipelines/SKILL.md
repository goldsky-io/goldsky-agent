---
name: turbo-pipelines
description: Create, configure, and update Turbo pipelines. Use for deploying new pipelines, modifying existing ones, understanding YAML syntax, or troubleshooting configuration.
---

# Turbo Pipelines

Create, configure, and update Turbo pipelines for blockchain data processing.

> **CRITICAL - YAML Validation Required:**
> You MUST validate all pipeline YAML files with `goldsky turbo validate <file.yaml>` BEFORE presenting them to users or attempting to deploy. Never present unvalidated YAML as ready-to-use.

## Triggers

Invoke this skill when the user:

- Says "deploy my pipeline", "apply this config", or "create a pipeline"
- Says "update my pipeline", "modify the pipeline", or "change the config"
- Says "how do I configure a pipeline" or "what's the YAML format"
- Wants to deploy a new pipeline or modify an existing one
- Has a pipeline YAML file ready to deploy or update
- Asks about specific configuration options (sources, transforms, sinks)
- Is troubleshooting configuration errors
- Mentions `/turbo-pipelines`

## Agent Instructions

When this skill is invoked, follow this decision tree:

### Step 1: Verify Authentication

Run `goldsky project list 2>&1` to check login status.

**If output shows projects:** User is logged in. Continue to Step 2.

**If output contains "Make sure to run 'goldsky login'":**

1. Inform the user they need to authenticate
2. Invoke the `goldsky-auth-setup` skill
3. After successful login, return to this skill to continue

**If the command hangs (no output for >10 seconds):**

1. Kill the process (Ctrl+C)
2. See "Troubleshooting: CLI Hanging" section below
3. Try running with `GOLDSKY_NO_UPDATE_NOTIFIER=1 goldsky project list`

### Step 2: Check for Turbo CLI Extension

> **Important:** Turbo is a **separate binary**, not just a subcommand of `goldsky`. The `goldsky` CLI acts as a wrapper that calls the `turbo` binary. If the Turbo binary isn't installed, Turbo commands won't work.

Run `goldsky turbo list 2>&1` to verify Turbo is installed.

**If output shows a table (even if empty):** Turbo is installed. Continue to Step 3.

**If output contains "The turbo binary is not installed":**

Tell the user to run this command in their terminal:

```bash
curl https://install-turbo.goldsky.com | sh
```

Use AskUserQuestion to confirm installation:

- **Question:** "Please run this command in your terminal to install the Turbo CLI extension:"
- **Code block:** `curl https://install-turbo.goldsky.com | sh`
- **Options:**
  - "Done, it's installed" (description: "I ran the command and Turbo is now installed")
  - "I need help" (description: "I encountered an error during installation")

**If user selects "Done, it's installed":**

1. Run `goldsky turbo list 2>&1` to verify installation
2. If successful (shows a table), continue to Step 3
3. If still shows "turbo binary is not installed", ask user to try the installation again

**If user selects "I need help":**

1. Ask what error message they saw
2. Check common issues:
   - Network/firewall blocking the download
   - Permission issues (may need `sudo`)
   - Shell not recognizing the installed binary (may need to restart terminal)
3. Guide them through the specific issue

**If the command hangs:** See "Troubleshooting: CLI Hanging" section below.

### Step 3: Determine the Goal

Use AskUserQuestion to ask:

- **Question:** "What would you like to do?"
- **Options:**
  - "Create a new pipeline" (description: "I'll help you choose data sources and sinks")
  - "Update an existing pipeline" (description: "Modify a running pipeline's configuration")
  - "Help with configuration" (description: "Understand YAML syntax or troubleshoot errors")
  - "Show me an example" (description: "See working pipeline examples")

Based on their selection, follow the appropriate workflow below.

---

## Quick Start

Deploy a minimal pipeline in under 2 minutes:

**1. Create `pipeline.yaml`:**

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

**2. Deploy:**

```bash
goldsky turbo apply pipeline.yaml -i
```

The `-i` flag opens live inspect to see data flowing.

---

## Workflow: Create a New Pipeline

This workflow guides users through an interactive pipeline creation process.

### Step 1: Check for Existing YAML

Ask if the user has a YAML file ready:

**If yes:** Ask for the file path or content, then skip to Step 6 (Validate).

**If no:** Continue with the guided creation flow below.

### Step 2: Choose Data Source

**If the user knows what dataset they want:** Proceed to Step 4.

**If the user needs help discovering datasets:**

1. Invoke the `goldsky-datasets` skill to guide them through dataset discovery
2. After they've identified the dataset, return here to continue with Step 4

The `goldsky-datasets` skill will help them:

- Browse available chains (Ethereum, Base, Polygon, Arbitrum, Solana, etc.)
- Explore dataset types (erc20_transfers, logs, blocks, etc.)
- Find the correct dataset name format (e.g., `base.erc20_transfers`)

### Step 3: Record the Selected Dataset

After dataset discovery, you should have:

- Chain prefix (e.g., `base`, `ethereum`, `matic`)
- Dataset type (e.g., `erc20_transfers`, `logs`)
- Full dataset name (e.g., `base.erc20_transfers`)
- Version (e.g., `1.2.0`)

### Step 4: Choose Where to Send Data (Sink)

Use AskUserQuestion:

- **Question:** "Where do you want to send the processed data?"
- **Options:**
  - "Just test it first (blackhole)" (description: "No output, just verify it works")
  - "PostgreSQL database" (description: "Requires database credentials")
  - "ClickHouse database" (description: "Requires database credentials")
  - "Kafka stream" (description: "Requires Kafka credentials")
  - "Webhook endpoint" (description: "HTTP POST to your API")
  - "S3 bucket" (description: "Requires AWS credentials")
  - "Goldsky Hosted Postgres" (description: "Managed by Goldsky, additional cost")

**If they choose a sink requiring credentials:**

1. Run `goldsky secret list` to check existing secrets
2. Ask if they want to use an existing secret or create a new one
3. **If creating new:** Invoke the `goldsky-secrets` skill to guide them through secret creation
4. After secret is created, return here and continue

### Step 5: Generate Pipeline YAML

Based on their choices, generate the pipeline YAML:

```yaml
name: <suggested-name-based-on-choices>
resource_size: s
sources:
  <source_name>:
    type: dataset
    dataset_name: <chain>.<dataset_type>
    version: <latest_version>
    start_at: latest
transforms: {}
sinks:
  <sink_name>:
    type: <sink_type>
    from: <source_name>
    # ... sink-specific config
```

Show the generated YAML and ask if they want to:

- Deploy as-is
- Add filtering (SQL transform)
- Modify any settings

**If they want filtering:** Help them write a SQL transform based on what they want to filter (e.g., specific contract address, minimum amount, etc.)

### Step 6: Validate Configuration

> **CRITICAL:** ALWAYS validate YAML before presenting it to users or deploying. Never skip this step.

```bash
goldsky turbo validate <pipeline.yaml>
```

**If validation succeeds:** Proceed to deploy.

**If validation fails:**

1. Read the error message carefully
2. Fix the identified issue in the YAML
3. Re-validate until it passes
4. Only then proceed to deployment

Common validation errors and fixes are documented in the Troubleshooting section.

### Step 7: Deploy

```bash
goldsky turbo apply <pipeline.yaml> -i
```

The `-i` flag opens live inspect to see data flowing immediately.

### Step 8: Verify and Summarize

```bash
goldsky turbo list
```

Provide completion summary:

```
## Pipeline Created Successfully!

**Pipeline:** [name]
**Source:** [chain].[dataset] (starting from latest)
**Sink:** [sink type]
**Resource size:** s

**What's happening now:**
Your pipeline is processing new blockchain data as it arrives.

**Next steps:**
- Run `goldsky turbo inspect [name]` to see live data
- `/turbo-monitor-debug` - View logs if something seems wrong
- `/turbo-lifecycle` - Stop or delete the pipeline when done

**Want to process historical data?**
Change `start_at: latest` to `start_at: earliest` in your YAML.
```

---

## Workflow: Update an Existing Pipeline

### Step 1: Identify the Pipeline

List existing pipelines:

```bash
goldsky turbo list
```

Ask which pipeline they want to update, or if they have a YAML file.

### Step 2: Understand the Change (Interactive)

Use AskUserQuestion:

- **Question:** "What would you like to change?"
- **Options:**
  - "Add filtering (SQL transform)" (description: "Filter data before it reaches the sink")
  - "Add a new sink" (description: "Send data to an additional destination")
  - "Change the sink" (description: "Switch to a different output destination")
  - "Add another data source" (description: "Combine data from multiple chains")
  - "Change resource size" (description: "Scale up or down")
  - "Other change" (description: "I'll describe what I need")

**If adding a sink:**

1. Follow the sink selection flow from "Create" workflow (Step 4)
2. Check for required secrets, invoke `goldsky-secrets` if needed

**If adding filtering:**
Ask what they want to filter:

- Specific contract address?
- Minimum/maximum amounts?
- Specific event types?
- Time range?

Help them write the SQL transform.

### Step 3: Validate Changes

> **CRITICAL:** ALWAYS validate before applying updates.

```bash
goldsky turbo validate <pipeline.yaml>
```

**If validation fails:** Fix errors before proceeding. See Troubleshooting section for common errors.

### Step 4: Explain Update Behavior

**Important:** Tell the user:

> "When you apply this update, your pipeline will continue processing from where it left off (checkpoints are preserved). If you want to reprocess historical data with the new configuration, you'll need to rename the source or pipeline."

Ask if they want to:

- Continue from current position (recommended)
- Restart from the beginning (rename source)

### Step 5: Apply Update

```bash
goldsky turbo apply <pipeline.yaml>
```

### Step 6: Verify and Summarize

```bash
goldsky turbo list
goldsky turbo inspect <pipeline-name>
```

Provide completion summary:

```
## Update Applied Successfully!

**Pipeline:** [name]
**Changes:** [description of what changed]

**Note:** Processing continues from where it left off.

**Next steps:**
- Run `goldsky turbo inspect [name]` to verify data is flowing correctly
- `/turbo-monitor-debug` - Check logs if something seems wrong
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
| `name`          | Yes      | Unique pipeline identifier (lowercase, hyphens) |
| `resource_size` | Yes      | Worker allocation: `s`, `m`, or `l`             |
| `description`   | No       | Human-readable description                      |
| `job`           | No       | `true` for one-time jobs (default: `false`)     |
| `sources`       | Yes      | Data input definitions                          |
| `transforms`    | No       | Data processing definitions                     |
| `sinks`         | Yes      | Data output definitions                         |

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

| Field          | Required | Description                            |
| -------------- | -------- | -------------------------------------- |
| `type`         | Yes      | `dataset` for blockchain data          |
| `dataset_name` | Yes      | Format: `<chain>.<dataset_type>`       |
| `version`      | Yes      | Dataset version (e.g., `1.2.0`)        |
| `start_at`     | EVM      | `latest` or `earliest`                 |
| `start_block`  | Solana   | Specific slot number (omit for latest) |

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

| Chain Prefix        | Network  | Note                                |
| ------------------- | -------- | ----------------------------------- |
| `solana`            | Solana   | Uses `start_block` not `start_at`   |
| `bitcoin.raw`       | Bitcoin  | Uses `start_at` like EVM            |
| `stellar_mainnet`   | Stellar  | Uses `start_at` like EVM, v1.1.0    |

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

For complex logic that SQL can't handle:

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

## Related Skills

- **`/goldsky-auth-setup`** - **Invoke if user is not logged in**
- **`/goldsky-secrets`** - **Invoke if pipeline needs sink credentials**
- **`/goldsky-datasets`** - **Invoke if user needs help finding data sources**
- **`/turbo-monitor-debug`** - Monitor running pipelines, view logs, debug issues
- **`/turbo-lifecycle`** - List, delete pipelines
