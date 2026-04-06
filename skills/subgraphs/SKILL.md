---
name: subgraphs
description: "Use this skill when the user asks about Goldsky Subgraphs — deploying, managing, or querying subgraphs. Triggers on: 'deploy a subgraph', 'migrate from The Graph', 'what is a subgraph', 'GraphQL endpoint', 'low-code or no-code subgraph', 'subgraph tags', 'subgraph webhooks', 'cross-chain subgraph', 'subgraph stalled', 'subgraph API key'. Also use this skill when the user wants to build a GraphQL API over onchain data, power a dApp frontend with indexed blockchain data, or reuse an existing TheGraph subgraph on Goldsky. For questions about streaming raw chain data directly to a database without GraphQL, use the turbo-builder or mirror skills instead."
---

# Goldsky Subgraphs

Subgraphs are hosted GraphQL APIs that index onchain events and expose them via a queryable endpoint. They are best for **frontend applications and dApps** that need flexible GraphQL queries over structured onchain data.

> **Could a Turbo pipeline solve this instead?**
> If your goal is to stream raw onchain data into a database (PostgreSQL, ClickHouse, Kafka, S3) — not query via GraphQL — a **Turbo pipeline** is faster, cheaper, and requires no custom indexing code. Say "help me build a Turbo pipeline" and the turbo-builder skill will guide you.

---

## When to Use Subgraphs

| Use case | Best tool |
| -------- | --------- |
| Frontend / dApp needs a GraphQL API | **Subgraphs** |
| Custom business logic in indexing handlers | **Subgraphs** |
| Migrate existing TheGraph subgraph | **Subgraphs** |
| Stream raw blockchain data to a database | **Turbo pipelines** |
| Real-time analytics in ClickHouse or Kafka | **Turbo pipelines** |
| Sync subgraph data into your own database | **Mirror + subgraph source** |

---

## Deploy a Subgraph

Goldsky supports three deployment paths:

### Option 1: From source (most common)

Requires a compiled subgraph in a local directory.

```bash
# Install CLI and log in
npm install -g @goldsky/cli
goldsky login

# Deploy
goldsky subgraph deploy <name>/<version> --path ./path/to/subgraph
```

### Option 2: No-code (via dashboard wizard)

Use the Goldsky dashboard to deploy pre-built subgraphs for common standards (ERC-20, ERC-721, etc.) without writing code. Navigate to **app.goldsky.com → Subgraphs → Create**.

### Option 3: Low-code (JSON config)

Define behavior in a JSON configuration file — add contract addresses and event handlers without full AssemblyScript code. See [docs.goldsky.com/subgraphs/guides/create-a-low-code-subgraph](https://docs.goldsky.com/subgraphs/guides/create-a-low-code-subgraph).

### Migrate from The Graph

One-step migration — no code changes needed:

```bash
goldsky subgraph deploy <name>/<version> \
  --from-url <your-thegraph-deployment-url>
```

See [docs.goldsky.com/subgraphs/migrate-from-the-graph](https://docs.goldsky.com/subgraphs/migrate-from-the-graph).

---

## GraphQL Endpoints

Every deployed subgraph gets a public GraphQL endpoint:

```
https://api.goldsky.com/api/public/<project-id>/subgraphs/<name>/<version>/gn
```

To get your endpoint URL:

```bash
goldsky subgraph list
```

### Public vs. Private endpoints

By default endpoints are public. To require an API key:

1. Go to **app.goldsky.com → Settings → API Keys** and create a key.
2. Add the `Authorization` header to requests:
   ```
   Authorization: Bearer <your-api-key>
   ```

---

## Subgraph Tags

Tags pin a human-readable alias (like `prod`) to a specific subgraph version, so your frontend URL never changes when you redeploy.

```bash
# Create a tag pointing to a version
goldsky subgraph tag create <name>/<version> --tag prod

# Tagged endpoint:
# https://api.goldsky.com/api/public/<project-id>/subgraphs/<name>/prod/gn
```

See [docs.goldsky.com/subgraphs/tags](https://docs.goldsky.com/subgraphs/tags).

---

## Common CLI Commands

| Action | Command |
| ------ | ------- |
| Deploy subgraph | `goldsky subgraph deploy <name>/<version> --path .` |
| List subgraphs | `goldsky subgraph list` |
| Delete subgraph | `goldsky subgraph delete <name>/<version>` |
| Create a tag | `goldsky subgraph tag create <name>/<version> --tag <tag>` |
| Update endpoint visibility | `goldsky subgraph update <name>/<version> --public-endpoint` |

---

## Cross-Chain Subgraphs

To index the same contract across multiple chains, deploy separate subgraphs per chain, then use a **Mirror pipeline** to merge them into one database table.

See [docs.goldsky.com/subgraphs/guides/create-a-cross-chain-subgraph](https://docs.goldsky.com/subgraphs/guides/create-a-cross-chain-subgraph).

---

## Webhooks

Subgraph webhooks send a payload to an HTTP endpoint on every entity change. Useful for notifications and push-based flows.

> **Tip:** If you need guaranteed delivery to a database, use Mirror to sync subgraph data instead of webhooks — it's more reliable.

See [docs.goldsky.com/subgraphs/webhooks](https://docs.goldsky.com/subgraphs/webhooks).

---

## Stalled Subgraphs

Goldsky auto-pauses subgraphs that have been stalled (not progressing) for an extended period and sends an email notification. To reactivate, redeploy or contact support.

---

## Related

- **`/turbo-builder`** — Build a streaming pipeline to a database instead of a GraphQL API
- **Goldsky docs:** [docs.goldsky.com/subgraphs/introduction](https://docs.goldsky.com/subgraphs/introduction)
