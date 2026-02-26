---
name: goldsky-datasets
description: Discover available blockchain datasets for Turbo pipelines. Use when exploring what data Goldsky offers, finding chain prefixes, or selecting the right dataset for a pipeline.
---

# Goldsky Dataset Discovery

Explore and discover available blockchain datasets for Turbo pipelines.

## Triggers

Invoke this skill when the user:

- Asks "what data does Goldsky have?" or "what chains are supported?"
- Wants to know if a specific chain or dataset is available
- Needs help finding the right dataset name format
- Says "help me find a dataset" or "what datasets are available?"
- Is unsure which dataset to use for their pipeline
- Asks about ERC-20 transfers, NFT data, logs, or other blockchain data types
- Mentions `/goldsky-datasets`

## Agent Instructions

> **IMPORTANT - Avoid `goldsky dataset list`:** This command is slow (30-60+ seconds) and often times out. Use the reference tables below instead. Only run the command if you need to verify a specific dataset exists or find an exact version.

When this skill is invoked:

### Step 1: Use the Reference Tables First

**Do NOT run `goldsky dataset list` upfront.** Instead:

1. Check the Verified Dataset Reference table below for exact dataset names
2. Use `goldsky turbo validate` on a test YAML to verify a dataset exists (fast, ~3 seconds)
3. Only run `goldsky dataset list | grep "specific_name"` if you need version info

### Step 2: Match User Need to Dataset

Based on what they're building, recommend directly from the reference:

| User Need                | Dataset                                  | Version                   |
| ------------------------ | ---------------------------------------- | ------------------------- |
| Token transfers (ERC-20) | `<chain>.erc20_transfers`                | 1.0.0 (eth), 1.2.0 (base) |
| NFT transfers (ERC-721)  | `<chain>.erc721_transfers`               | 1.0.0                     |
| All transactions         | `<chain>.raw_transactions`               | 1.0.0                     |
| Event logs               | `<chain>.logs` or `<chain>.raw_logs`     | 1.0.0                     |
| Block data               | `<chain>.blocks` or `<chain>.raw_blocks` | 1.0.0                     |

### Step 3: Validate Before Presenting

**ALWAYS validate the dataset exists** before giving it to the user:

```bash
# Quick validation test (fast, ~3 seconds)
goldsky turbo validate - <<'EOF'
name: test
resource_size: s
sources:
  test:
    type: dataset
    dataset_name: <chain>.<dataset_type>
    version: 1.0.0
    start_at: latest
transforms: {}
sinks:
  out:
    type: blackhole
    from: test
EOF
```

If validation fails with "Dataset not found", try alternate naming (see Verified Dataset Reference).

---

## Dataset Reference Files

> **Detailed dataset and chain information is in the `data/` folder.**

| File                     | Contents                                                     |
| ------------------------ | ------------------------------------------------------------ |
| `verified-datasets.json` | All validated datasets with versions, schemas, and use cases |
| `chain-prefixes.json`    | All chain prefixes, chain IDs, and common mistakes           |

**Data location:** `data/` (relative to this skill's directory)

---

## Quick Reference

| Action             | Command                               | Notes                        |
| ------------------ | ------------------------------------- | ---------------------------- |
| Validate dataset   | `goldsky turbo validate file.yaml`    | **Preferred - fast (3s)**    |
| Search for dataset | `goldsky dataset list \| grep "name"` | Slow (30-60s), use sparingly |
| List all datasets  | `goldsky dataset list`                | **Very slow - avoid**        |

---

## Common Datasets

| What You Need            | Dataset                    | Example                              |
| ------------------------ | -------------------------- | ------------------------------------ |
| Token transfers (ERC-20) | `<chain>.erc20_transfers`  | `base.erc20_transfers` (v1.2.0)      |
| NFT transfers (ERC-721)  | `<chain>.erc721_transfers` | `ethereum.erc721_transfers` (v1.0.0) |
| Transactions             | `<chain>.raw_transactions` | `ethereum.raw_transactions` (v1.0.0) |
| Event logs               | `<chain>.raw_logs`         | `base.raw_logs` (v1.0.0)             |
| Solana tokens            | `solana.token_transfers`   | v1.0.0                               |
| Bitcoin transactions     | `bitcoin.raw.transactions` | v1.0.0                               |
| Stellar transfers        | `stellar_mainnet.transfers`| v1.1.0                               |

> **Important:** Use `raw_transactions`, NOT `transactions`

---

## Popular Chain Prefixes

| Chain     | Prefix             | Note                              |
| --------- | ------------------ | --------------------------------- |
| Ethereum  | `ethereum`         |                                   |
| Base      | `base`             |                                   |
| Polygon   | `matic`            | **NOT** `polygon`                 |
| Arbitrum  | `arbitrum`         |                                   |
| Optimism  | `optimism`         |                                   |
| BSC       | `bsc`              |                                   |
| Avalanche | `avalanche`        |                                   |
| Solana    | `solana`           | Uses `start_block` not `start_at` |
| Bitcoin   | `bitcoin.raw`      | Uses `start_at` like EVM          |
| Stellar   | `stellar_mainnet`  | Uses `start_at` like EVM          |
| Sui       | `sui`              | Uses `start_at` like EVM          |
| NEAR      | `near`             | Uses `start_at` like EVM          |
| Starknet  | `starknet`         | Uses `start_at` like EVM          |
| Fogo      | `fogo`             | Uses `start_at` like EVM          |

**See `data/chain-prefixes.json` for complete list with chain IDs.**

---

## Common Dataset Types

### EVM Chains

| Dataset Type        | Description                 | Use Case                             |
| ------------------- | --------------------------- | ------------------------------------ |
| `blocks`            | Block headers with metadata | Block explorers, timing analysis     |
| `raw_transactions`  | Transaction data            | Wallet activity, gas analysis        |
| `raw_logs`          | Raw event logs              | Custom event filtering               |
| `raw_traces`        | Internal transaction traces | MEV analysis, contract interactions  |
| `erc20_transfers`   | Fungible token transfers    | Token tracking, DeFi analytics       |
| `erc721_transfers`  | NFT transfers               | NFT marketplaces, ownership tracking |
| `erc1155_transfers` | Multi-token transfers       | Gaming, multi-token standards        |
| `decoded_logs`      | ABI-decoded event logs      | Specific contract events             |

> **Important:** Use `raw_transactions`, NOT `transactions`. Use `raw_logs`, NOT `logs` (though `logs` works as an alias on some chains).

### Solana

| Dataset Type                     | Description                       | Use Case                     |
| -------------------------------- | --------------------------------- | ---------------------------- |
| `blocks`                         | Block data with leader info       | Chain analysis               |
| `transactions`                   | Transaction data with balances    | Wallet activity              |
| `transactions_with_instructions` | Transactions + nested instructions| Multi-instruction analysis   |
| `instructions`                   | Individual instructions           | Program-specific analysis    |
| `token_transfers`                | SPL token transfers               | Token tracking               |
| `native_balances`                | SOL balance changes               | Whale tracking               |
| `token_balances`                 | SPL token balance changes         | Portfolio tracking           |
| `rewards`                        | Validator rewards                 | Staking analysis             |

### Bitcoin

| Dataset Type           | Description              | Use Case                     |
| ---------------------- | ------------------------ | ---------------------------- |
| `bitcoin.raw.blocks`       | Block data (hash, difficulty, size) | Network analysis     |
| `bitcoin.raw.transactions` | Transactions (inputs, outputs, values) | Payment tracking |

### Stellar

All datasets use version `1.1.0`:

| Dataset Type                       | Description                       | Use Case                     |
| ---------------------------------- | --------------------------------- | ---------------------------- |
| `stellar_mainnet.transactions`     | All network transactions          | Account monitoring           |
| `stellar_mainnet.transfers`        | All transfer events               | Asset tracking               |
| `stellar_mainnet.events`           | All events (contract + operation) | Contract monitoring          |
| `stellar_mainnet.operations`       | Operations within transactions    | Action tracking              |
| `stellar_mainnet.ledger_entries`   | Ledger state changes              | State analysis               |
| `stellar_mainnet.ledgers`          | Ledger metadata                   | Network analysis             |
| `stellar_mainnet.balances`         | Account balance changes           | Balance tracking             |

### Sui

| Dataset Type            | Description                       | Use Case                     |
| ----------------------- | --------------------------------- | ---------------------------- |
| `sui.checkpoints`       | Checkpoint data                   | Chain analysis               |
| `sui.transactions`      | Transaction data                  | Activity monitoring          |
| `sui.events`            | Move contract events              | dApp event tracking          |
| `sui.packages`          | Deployed Move packages            | Package discovery            |
| `sui.epochs`            | Epoch data with validators        | Staking/validator analysis   |

### NEAR

| Dataset Type                 | Description                       | Use Case                     |
| ---------------------------- | --------------------------------- | ---------------------------- |
| `near.receipts`              | Execution receipts                | Contract interaction tracking|
| `near.transactions`          | Signed transactions               | Activity monitoring          |
| `near.execution_outcomes`    | Execution results                 | Success/failure analysis     |

### Starknet

| Dataset Type                 | Description                       | Use Case                     |
| ---------------------------- | --------------------------------- | ---------------------------- |
| `starknet.blocks`            | Block data                        | Chain analysis               |
| `starknet.transactions`      | Transaction data                  | Activity monitoring          |
| `starknet.events`            | Contract events                   | dApp event tracking          |
| `starknet.messages`          | L1↔L2 messages                    | Bridge monitoring            |

### Fogo

| Dataset Type                          | Description                     | Use Case                     |
| ------------------------------------- | ------------------------------- | ---------------------------- |
| `fogo.transactions_with_instructions` | Transactions with instructions  | Full activity tracking       |
| `fogo.rewards`                        | Validator rewards               | Staking analysis             |
| `fogo.blocks`                         | Block data                      | Chain analysis               |

---

## Dataset Name Format

All datasets follow the pattern: `<chain_prefix>.<dataset_type>`

**Examples:**

- `ethereum.erc20_transfers` - ERC-20 transfers on Ethereum mainnet
- `base.logs` - All event logs on Base
- `matic.blocks` - Block data on Polygon
- `solana.token_transfers` - SPL token transfers on Solana

---

## Finding Dataset Versions

Datasets are versioned. To find available versions:

```bash
goldsky dataset list | grep "base.erc20"
```

**Common versions:**

- `1.0.0` - Initial version
- `1.2.0` - Enhanced schema (common for ERC-20 transfers)

When in doubt, use the latest version shown in `goldsky dataset list`.

---

## Common Discovery Patterns

### "I want to track USDC transfers on Base"

1. Dataset: `base.erc20_transfers`
2. Filter by contract address in your pipeline transform:

```yaml
transforms:
  usdc_only:
    type: sql
    primary_key: id
    sql: |
      SELECT * FROM source_name
      WHERE address = lower('0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913')
```

### "I want all NFT activity on Ethereum"

Dataset: `ethereum.erc721_transfers`

### "I want to monitor a specific smart contract"

1. Dataset: `<chain>.logs` for raw events, or `<chain>.decoded_logs` for decoded events
2. Filter by contract address in your transform

### "I need multi-chain data"

Use multiple sources in your pipeline:

```yaml
sources:
  eth_transfers:
    type: dataset
    dataset_name: ethereum.erc20_transfers
    version: 1.0.0
    start_at: latest
  base_transfers:
    type: dataset
    dataset_name: base.erc20_transfers
    version: 1.2.0
    start_at: latest
```

---

## Troubleshooting

### Dataset not found

```
Error: Source 'my_source' references unknown dataset 'invalid.dataset'
```

**Fix:**

1. Check the chain prefix is correct (e.g., `matic` not `polygon`)
2. Check the dataset type exists (e.g., `erc20_transfers` not `erc20`)
3. Run `goldsky dataset list` to see all available options

### Chain not listed

If you can't find a chain in the tables above:

```bash
goldsky dataset list | grep -i "<chain_name>"
```

Some chains use non-obvious prefixes (e.g., Polygon uses `matic`).

### Version mismatch

```
Error: Version '2.0.0' not found for dataset 'base.erc20_transfers'
```

**Fix:** Check available versions:

```bash
goldsky dataset list | grep "base.erc20_transfers"
```

Use a version that exists in the output.

---

## Related Skills

- **`/turbo-pipelines`** - Create pipelines using discovered datasets
- **`/goldsky-auth-setup`** - Set up CLI authentication first
