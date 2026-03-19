---
name: subgraph-config
description: "Goldsky subgraph configuration reference — the authoritative source for instant subgraph JSON config fields, subgraph.yaml manifest structure, CLI deploy flags, and supported chain slugs for subgraphs. Use whenever the user asks about specific config fields: what goes in the 'abis' section, how to configure 'instances' with multiple chains, what enrichment options are available, how to set start_block in instant config, what the --from-abi flag expects, or how subgraph.yaml differs from instant config JSON. Also use for 'what chains support subgraphs' or 'what is the chain slug for Polygon subgraphs'. For interactive subgraph building end-to-end, use /subgraph-builder instead. For webhook configuration, use /subgraph-lifecycle."
---

# Subgraph Configuration Reference

Configuration reference for Goldsky subgraphs. This is a lookup reference — for interactive subgraph building, use `/subgraph-builder`. For troubleshooting, use `/subgraph-doctor`.

---

## Quick Start

Deploy a subgraph from source code:

```bash
goldsky subgraph deploy my-subgraph/1.0.0 --path .
```

Deploy an instant subgraph from ABI config:

```bash
goldsky subgraph deploy my-subgraph/1.0.0 --from-abi config.json
```

Deploy via no-code wizard (interactive):

```bash
goldsky subgraph deploy my-subgraph/1.0.0 --from-abi
```

---

## Prerequisites

- [ ] **Goldsky CLI installed** — `curl https://goldsky.com | sh` (macOS/Linux) or `npm install -g @goldskycom/cli` (Windows)
- [ ] **Logged in** — `goldsky login` with your API key
- [ ] ABI file(s) ready (for instant subgraphs) OR subgraph source code (subgraph.yaml, schema.graphql, mappings)

---

## Deployment Methods

| Method | Command | When to Use |
| -------- | ------- | ----------- |
| No-code wizard | `goldsky subgraph deploy name/version --from-abi` | Quick exploration, single contract, auto-fetches ABI |
| Low-code JSON | `goldsky subgraph deploy name/version --from-abi config.json` | Multiple contracts, enrichments, custom schemas |
| Source code | `goldsky subgraph deploy name/version --path .` | Custom mapping logic, complex entity relationships |
| IPFS migration | `goldsky subgraph deploy name/version --from-ipfs-hash <hash>` | Migrating from TheGraph |
| URL migration | `goldsky subgraph deploy name/version --from-url <endpoint>` | Migrating from any GraphQL endpoint |

---

## CLI Deploy Command Reference

```
goldsky subgraph deploy <name/version>
```

### Deploy Flags

| Flag | Type | Description |
| ---- | ---- | ----------- |
| `--path` | string | Path to subgraph source code directory |
| `--from-abi` | string | Path to instant subgraph JSON config (or omit value for interactive wizard) |
| `--from-ipfs-hash` | string | IPFS hash from TheGraph deployment |
| `--from-url` | string | GraphQL endpoint URL of an existing subgraph |
| `--ipfs-gateway` | string | IPFS gateway URL (default: `https://ipfs.network.thegraph.com`) |
| `--tag` | string | Tag the subgraph after deployment (comma-separated for multiple) |
| `--start-block` | number | Override the start block |
| `--graft-from` | string | Graft from existing subgraph: `name/version` |
| `--remove-graft` | boolean | Remove grafts before deployment (default: false) |
| `--enable-call-handlers` | boolean | Enable call handler indexing (only with `--from-abi`) |
| `--description` | string | Description/notes for the subgraph |

### Init Command (Scaffold a Subgraph)

```
goldsky subgraph init [name/version]
```

| Flag | Type | Description |
| ---- | ---- | ----------- |
| `--from-config` | string | Path to instant subgraph JSON config |
| `--abi` | string | ABI source(s) for contract(s) |
| `--contract` | string | Contract address(es) to index |
| `--contract-events` | string | Event names to index |
| `--contract-calls` | string | Call names to index |
| `--network` | string | Network slug(s) for contracts |
| `--contract-name` | string | Name of the contract(s) |
| `--start-block` | string | Block to start indexing from |
| `--call-handlers` | boolean | Enable call handlers |
| `--build` | boolean | Build after scaffolding |
| `--deploy` | boolean | Deploy after build |

---

## Instant Subgraph JSON Configuration (Version 1)

Instant subgraphs use a JSON configuration file deployed with `--from-abi config.json`. This generates all subgraph code automatically.

### Schema Overview

```json
{
  "version": "1",
  "name": "my-subgraph",
  "abis": {
    "MyContract": {
      "path": "./abi.json"
    }
  },
  "instances": [
    {
      "abi": "MyContract",
      "address": "0x1234...abcd",
      "chain": "mainnet",
      "startBlock": 12345678
    }
  ]
}
```

### Top-Level Fields

| Field | Required | Type | Description |
| ----- | -------- | ---- | ----------- |
| `version` | Yes | string | Must be `"1"` |
| `name` | No | string | Subgraph name (can also be set via CLI) |
| `abis` | Yes | object | Map of ABI names to ABI source configurations |
| `instances` | Yes | array | List of contract instances to index |
| `enableCallHandlers` | No | boolean | Enable call handler indexing for all instances |

### ABI Configuration (`abis`)

Each key in `abis` is a name you choose. The value is an ABI source:

**File path:**
```json
"abis": {
  "ERC20": {
    "path": "./erc20-abi.json"
  }
}
```

**Inline ABI (raw array):**
```json
"abis": {
  "ERC20": [
    {
      "type": "event",
      "name": "Transfer",
      "inputs": [
        {"indexed": true, "name": "from", "type": "address"},
        {"indexed": true, "name": "to", "type": "address"},
        {"indexed": false, "name": "value", "type": "uint256"}
      ]
    }
  ]
}
```

### Instance Configuration (`instances`)

Each instance represents a contract deployment to index:

| Field | Required | Type | Description |
| ----- | -------- | ---- | ----------- |
| `abi` | Yes | string | Must match a key in `abis` |
| `address` | Yes | string | Contract address (0x-prefixed) |
| `chain` | Yes | string | Chain slug (e.g., `mainnet`, `base`, `matic`) |
| `startBlock` | No | number | Block to start indexing from |

**Multiple contracts:**
```json
"instances": [
  {
    "abi": "ERC20",
    "address": "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48",
    "chain": "mainnet",
    "startBlock": 6082465
  },
  {
    "abi": "ERC721",
    "address": "0xBC4CA0EdA7647A8aB7C2061c2E118A18a936f13D",
    "chain": "mainnet",
    "startBlock": 12287507
  }
]
```

**Same contract, multiple chains:**
```json
"instances": [
  {
    "abi": "USDC",
    "address": "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48",
    "chain": "mainnet",
    "startBlock": 6082465
  },
  {
    "abi": "USDC",
    "address": "0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913",
    "chain": "base",
    "startBlock": 1000000
  }
]
```

> **Note:** Multiple chains in the configuration result in multiple subgraphs being deployed.

### Enrichments (eth_call)

See `references/enrichments.md` for full enrichment configuration.

---

## Source Code Subgraph Structure

When deploying with `--path .`, your directory should contain:

```
my-subgraph/
  subgraph.yaml      # Manifest — data sources, entities, event handlers
  schema.graphql      # Entity definitions (GraphQL schema)
  src/
    mapping.ts        # AssemblyScript event handlers
  abis/
    MyContract.json   # Contract ABI(s)
```

### subgraph.yaml Structure

```yaml
specVersion: 0.0.4
schema:
  file: ./schema.graphql
dataSources:
  - kind: ethereum
    name: MyContract
    network: mainnet
    source:
      address: "0x1234...abcd"
      abi: MyContract
      startBlock: 12345678
    mapping:
      kind: ethereum/events
      apiVersion: 0.0.6
      language: wasm/assemblyscript
      entities:
        - Transfer
      abis:
        - name: MyContract
          file: ./abis/MyContract.json
      eventHandlers:
        - event: Transfer(indexed address,indexed address,uint256)
          handler: handleTransfer
      callHandlers:    # Optional
        - function: approve(address,uint256)
          handler: handleApprove
      file: ./src/mapping.ts
```

---

## GraphQL Endpoint Formats

After deployment, you receive GraphQL endpoints:

| Type | Format |
| ---- | ------ |
| Versioned (private) | `https://api.goldsky.com/api/private/<project-hash>/subgraphs/<name>/<version>/gn` |
| Tagged (private) | `https://api.goldsky.com/api/private/<project-hash>/subgraphs/<name>/<tag>/gn` |
| Public | `https://api.goldsky.com/api/public/<project-hash>/subgraphs/<name>/<version>/gn` |

**Private endpoints** require a Bearer token in the Authorization header:
```
Authorization: Bearer <your-api-key>
```

To toggle public/private endpoints:
```bash
goldsky subgraph update name/version --public-endpoint true
goldsky subgraph update name/version --private-endpoint true
```

---

## Common Chain Slugs (Subgraphs)

> **Full list:** See `data/subgraph-chain-slugs.json` or [Goldsky Supported Networks](https://docs.goldsky.com/chains/supported-networks).

| Chain | Slug | Notes |
| ----- | ---- | ----- |
| Ethereum | `mainnet` | **Not** `ethereum` — different from Turbo datasets |
| Base | `base` | |
| Polygon | `matic` | **Not** `polygon` |
| Arbitrum One | `arbitrum-one` | |
| Optimism | `optimism` | |
| BNB Chain | `bsc` | |
| Avalanche | `avalanche` | |
| Gnosis | `xdai` | **Not** `gnosis` |
| Fantom | `fantom` | |
| zkSync Era | `zksync-era` | |
| Linea | `linea` | |
| Scroll | `scroll` | |
| Blast | `blast` | |
| Zora | `zora` | |
| Mode | `mode-mainnet` | |

> **Important:** Subgraph chain slugs differ from Turbo dataset prefixes in some cases (e.g., `mainnet` vs `ethereum`, `arbitrum-one` vs `arbitrum`). Always use the subgraph-specific slug.

---

## Common Configuration Patterns

### Minimal Instant Subgraph (Single Contract)

```json
{
  "version": "1",
  "abis": {
    "USDC": {
      "path": "./usdc-abi.json"
    }
  },
  "instances": [
    {
      "abi": "USDC",
      "address": "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48",
      "chain": "mainnet",
      "startBlock": 6082465
    }
  ]
}
```

### Multiple Contracts with Different ABIs

```json
{
  "version": "1",
  "abis": {
    "ERC20": { "path": "./erc20-abi.json" },
    "UniswapV2Pair": { "path": "./uniswap-pair-abi.json" }
  },
  "instances": [
    {
      "abi": "ERC20",
      "address": "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48",
      "chain": "mainnet",
      "startBlock": 6082465
    },
    {
      "abi": "UniswapV2Pair",
      "address": "0xB4e16d0168e52d35CaCD2c6185b44281Ec28C9Dc",
      "chain": "mainnet",
      "startBlock": 10008355
    }
  ]
}
```

---

## Related

- **`/subgraph-architecture`** — High-level design decisions (subgraph vs pipeline, cross-chain strategies)
- **`/subgraph-builder`** — Interactive wizard to deploy subgraphs step-by-step
- **`/subgraph-doctor`** — Diagnose and fix subgraph issues
- **`/subgraph-lifecycle`** — Pause, start, delete, tags, webhooks
- **`/subgraph-migrate`** — Migrate from TheGraph or Alchemy
