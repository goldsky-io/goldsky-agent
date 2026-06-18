---
name: subgraphs
description: "Use this skill when the user asks about Goldsky Subgraphs — deploying, managing, or querying subgraphs. Triggers on: 'deploy a subgraph', 'what is a subgraph', 'GraphQL endpoint', 'low-code or no-code subgraph', 'subgraph tags', 'subgraph webhooks', 'cross-chain subgraph', 'subgraph API key', 'init subgraph', 'scaffold subgraph', 'subgraph logs', 'pause subgraph', 'start subgraph', 'graft subgraph'. Also use this skill when the user wants to build a GraphQL API over onchain data or power a dApp frontend with indexed blockchain data. For a subgraph that is failing, stalled, stuck syncing, or won't deploy, use the subgraph-doctor skill. For migrating a subgraph off The Graph, use the subgraph-migrate-thegraph skill. For questions about streaming raw chain data directly to a database without GraphQL, use the turbo-builder or mirror skills instead."
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

## Initialize a Subgraph

Scaffold a new subgraph project locally:

```bash
goldsky subgraph init my-subgraph/1.0.0 --target-path ./my-subgraph
```

### Key init flags

| Flag | Description |
| ---- | ----------- |
| `--target-path <path>` | Directory to write subgraph files to |
| `--from-config <path>` | Path to instant subgraph JSON configuration file |
| `--abi <source>` | ABI source for contract(s) |
| `--contract <address>` | Contract address(es) to watch |
| `--contract-events <names>` | Event names to index |
| `--contract-calls <names>` | Call names to index |
| `--contract-name <name>` | Name of the contract(s) |
| `--network <network>` | Network for contract(s) — see docs for supported networks |
| `--start-block <block>` | Block to start indexing from |
| `--description <text>` | Subgraph description |
| `--call-handlers` | Enable call handlers |
| `--build` | Build the subgraph after writing files |
| `--deploy` | Deploy the subgraph after build |
| `--force` | Overwrite existing files at the target path |

---

## Deploy a Subgraph

Goldsky supports multiple deployment paths:

### From source (most common)

Requires a compiled subgraph in a local directory.

```bash
# Install CLI and log in
curl https://goldsky.com | sh
goldsky login

# Deploy from local build output
goldsky subgraph deploy my-subgraph/1.0.0 --path ./build
```

### From ABI (instant subgraph)

Generate and deploy a subgraph directly from a contract ABI — no AssemblyScript needed:

```bash
goldsky subgraph deploy my-subgraph/1.0.0 --from-abi ./MyContract.json
```

### From IPFS hash

Deploy a subgraph already published to IPFS:

```bash
goldsky subgraph deploy my-subgraph/1.0.0 --from-ipfs-hash QmXyz...
```

Use `--ipfs-gateway <url>` to specify a custom gateway (defaults to `https://ipfs.network.thegraph.com`).

### No-code (dashboard wizard)

Use the Goldsky dashboard to deploy pre-built subgraphs for common standards (ERC-20, ERC-721, etc.) without writing code. Navigate to **app.goldsky.com → Subgraphs → Create**.

### Migrate from The Graph

One-step migration, no code changes — deploy from your existing endpoint or IPFS hash:

```bash
goldsky subgraph deploy my-subgraph/1.0.0 --from-url <your-thegraph-deployment-url>
```

> For a guided migration (path selection, verifying sync, migrating tags, swapping your endpoint), use **`/subgraph-migrate-thegraph`**.

### Deploy flags reference

| Flag | Description |
| ---- | ----------- |
| `--path <dir>` | Path to compiled subgraph directory |
| `--from-url <url>` | GraphQL endpoint of a publicly deployed subgraph (The Graph migration) |
| `--from-ipfs-hash <hash>` | IPFS hash of a publicly deployed subgraph |
| `--from-abi <path>` | Generate a subgraph from an ABI file |
| `--ipfs-gateway <url>` | Custom IPFS gateway (default: `https://ipfs.network.thegraph.com`) |
| `--tag <tags>` | Tag the subgraph after deployment (comma-separated for multiple) |
| `--start-block <number>` | Override start block |
| `--graft-from <name/version>` | Graft from the latest block of an existing subgraph |
| `--remove-graft` | Remove grafts from the subgraph prior to deployment |
| `--enable-call-handlers` | Enable call handlers (only with `--from-abi`) |
| `--description <text>` | Description/notes for the subgraph |

> **Note:** `--path`, `--from-url`, `--from-ipfs-hash`, and `--from-abi` are mutually exclusive — use only one.

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

### Public vs. private endpoints

By default endpoints are public. To control endpoint visibility:

```bash
# Disable public endpoint
goldsky subgraph update my-subgraph/1.0.0 --public-endpoint disabled

# Enable private endpoint (requires API key)
goldsky subgraph update my-subgraph/1.0.0 --private-endpoint enabled
```

To require an API key for private endpoints:

1. Go to **app.goldsky.com → Settings → API Keys** and create a key.
2. Add the `Authorization` header to requests:
   ```
   Authorization: Bearer <your-api-key>
   ```

---

## Subgraph Tags

Tags pin a human-readable alias (like `prod`) to a specific subgraph version, so your frontend URL never changes when you redeploy.

```bash
# Create or update a tag
goldsky subgraph tag create my-subgraph/1.0.0 --tag prod

# Tagged endpoint:
# https://api.goldsky.com/api/public/<project-id>/subgraphs/my-subgraph/prod/gn

# Delete a tag
goldsky subgraph tag delete my-subgraph/1.0.0 --tag prod
```

You can also tag at deploy time:

```bash
goldsky subgraph deploy my-subgraph/2.0.0 --path ./build --tag prod
```

See [docs.goldsky.com/subgraphs/tags](https://docs.goldsky.com/subgraphs/tags).

---

## Webhooks

Subgraph webhooks send a payload to an HTTP endpoint on every entity change (`INSERT`, `UPDATE`, `DELETE`). Useful for notifications and push-based flows.

```bash
# Create a webhook
goldsky subgraph webhook create my-subgraph/1.0.0 \
  --name my-webhook \
  --url https://example.com/hook \
  --entity Transfer \
  --secret my-secret

# List all webhooks
goldsky subgraph webhook list

# List available entities for a subgraph
goldsky subgraph webhook list-entities my-subgraph/1.0.0

# Delete a webhook
goldsky subgraph webhook delete my-webhook
```

| Flag | Description |
| ---- | ----------- |
| `--name <name>` | Webhook name (must be unique) — required |
| `--url <url>` | URL to send events to — required |
| `--entity <entity>` | Subgraph entity to send events for — required |
| `--secret <secret>` | Secret included with each webhook request |

> **Tip:** If you need guaranteed delivery to a database, use Mirror to sync subgraph data instead of webhooks — it's more reliable.

See [docs.goldsky.com/subgraphs/webhooks](https://docs.goldsky.com/subgraphs/webhooks).

---

## Managing Subgraphs

### List subgraphs

```bash
# List all subgraphs
goldsky subgraph list

# List a specific subgraph
goldsky subgraph list my-subgraph/1.0.0

# Show only tags or deployments
goldsky subgraph list --filter tags
goldsky subgraph list --filter deployments

# Summary view
goldsky subgraph list --summary
```

### Update a subgraph

```bash
goldsky subgraph update my-subgraph/1.0.0 \
  --public-endpoint enabled \
  --private-endpoint disabled \
  --description "Production deployment"
```

| Flag | Values | Description |
| ---- | ------ | ----------- |
| `--public-endpoint` | `enabled` / `disabled` | Toggle public endpoint visibility |
| `--private-endpoint` | `enabled` / `disabled` | Toggle private endpoint (requires API key) |
| `--description` | text | Description/notes for the subgraph |

### Pause and resume

```bash
# Pause a subgraph (stops indexing)
goldsky subgraph pause my-subgraph/1.0.0

# Resume a paused subgraph
goldsky subgraph start my-subgraph/1.0.0
```

### Delete a subgraph

```bash
goldsky subgraph delete my-subgraph/1.0.0

# Skip confirmation prompt
goldsky subgraph delete my-subgraph/1.0.0 --force
```

---

## Logs and Debugging

Tail a subgraph's logs to diagnose issues:

```bash
# View recent logs
goldsky subgraph log my-subgraph/1.0.0

# Logs from the last hour, errors only
goldsky subgraph log my-subgraph/1.0.0 --since 1h --filter error

# JSON format for parsing
goldsky subgraph log my-subgraph/1.0.0 --format json
```

| Flag | Default | Description |
| ---- | ------- | ----------- |
| `--since <duration>` | `1m` | Show logs newer than duration (e.g. `5s`, `2m`, `3h`) |
| `--format <format>` | `text` | Output format: `pretty`, `json`, or `text` |
| `--filter <level>` | `info` | Minimum log level: `error`, `warn`, `info`, `debug` |
| `--levels <levels>` | — | Explicit comma-separated log levels to include |
| `--interval <seconds>` | `5` | Seconds between log checks |

> **Subgraph failing, stalled, stuck syncing, or won't deploy?** Use **`/subgraph-doctor`** for a step-by-step diagnostic workflow (status checks, log reading, the `_meta` query, error-pattern matching, and fixes).

---

## Cross-Chain Subgraphs

To index the same contract across multiple chains, deploy separate subgraphs per chain, then use a **Mirror pipeline** to merge them into one database table.

See [docs.goldsky.com/subgraphs/introduction](https://docs.goldsky.com/subgraphs/introduction).

---

## CLI Command Reference

| Action | Command |
| ------ | ------- |
| Initialize subgraph | `goldsky subgraph init <name/version>` |
| Deploy from source | `goldsky subgraph deploy <name/version> --path .` |
| Deploy from The Graph | `goldsky subgraph deploy <name/version> --from-url <url>` |
| Deploy from ABI | `goldsky subgraph deploy <name/version> --from-abi <path>` |
| Deploy from IPFS | `goldsky subgraph deploy <name/version> --from-ipfs-hash <hash>` |
| List subgraphs | `goldsky subgraph list` |
| Delete subgraph | `goldsky subgraph delete <name/version>` |
| Pause subgraph | `goldsky subgraph pause <name/version>` |
| Start subgraph | `goldsky subgraph start <name/version>` |
| Update subgraph | `goldsky subgraph update <name/version> --public-endpoint enabled` |
| Tail logs | `goldsky subgraph log <name/version>` |
| Create tag | `goldsky subgraph tag create <name/version> --tag <tag>` |
| Delete tag | `goldsky subgraph tag delete <name/version> --tag <tag>` |
| Create webhook | `goldsky subgraph webhook create <name/version> --name <n> --url <u> --entity <e>` |
| List webhooks | `goldsky subgraph webhook list` |
| Delete webhook | `goldsky subgraph webhook delete <webhook-name>` |
| List webhook entities | `goldsky subgraph webhook list-entities <name/version>` |

---

## Related

- **`/subgraph-doctor`** — Diagnose and fix a failing, stalled, or stuck subgraph
- **`/subgraph-migrate-thegraph`** — Guided migration of a subgraph from The Graph
- **`/turbo-builder`** — Build a streaming pipeline to a database instead of a GraphQL API
- **Goldsky docs:** [docs.goldsky.com/subgraphs/introduction](https://docs.goldsky.com/subgraphs/introduction)
