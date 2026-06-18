---
name: subgraph-builder
description: "Build, author, and deploy Goldsky Subgraphs — hosted GraphQL APIs over onchain data. Use this skill when the user wants to create, scaffold, write, or deploy a subgraph; design a subgraph schema or entities; write or fix AssemblyScript mapping handlers; configure subgraph.yaml (data sources, event/call/block handlers, templates); deploy from source, an ABI (instant/no-code), or IPFS; or set up GraphQL endpoints, tags, and webhooks. Triggers on: 'build a subgraph', 'create a subgraph', 'deploy a subgraph', 'init subgraph', 'scaffold subgraph', 'write a subgraph mapping', 'design a subgraph schema', 'subgraph entities', 'subgraph.yaml', 'event handlers', 'no-code / low-code / instant subgraph', 'subgraph from ABI', 'GraphQL endpoint', 'subgraph tags', 'subgraph webhooks', 'cross-chain subgraph', 'index a contract with a GraphQL API'. For a subgraph that is failing, stalled, or won't deploy, use /subgraph-doctor. For migrating an existing subgraph off The Graph, use /subgraph-migrate. For exhaustive CLI flags, use /cli-reference. For streaming raw chain data to a database without GraphQL, use /turbo-builder."
---

# Subgraph Builder

Build a Goldsky Subgraph end-to-end: design the schema, write mappings, configure the manifest, then build and deploy to a hosted GraphQL endpoint. Subgraphs are best for **dApp frontends and apps that need flexible GraphQL queries** over structured onchain data. Subgraphs are **EVM-only**.

> **Could a Turbo pipeline solve this instead?**
> If the goal is to stream raw onchain data into a database (PostgreSQL, ClickHouse, Kafka, S3) rather than query via GraphQL, a **Turbo pipeline** is faster, cheaper, and needs no custom indexing code. Use `/turbo-builder`. Subgraphs win when you specifically need a GraphQL API or custom entity-relationship modeling.

## Boundaries

- Build and author NEW subgraphs (schema, mappings, manifest, deploy, endpoints, tags, webhooks).
- Do not diagnose broken/stalled subgraphs — use `/subgraph-doctor`.
- Do not run The Graph migrations — use `/subgraph-migrate`.
- For exhaustive `goldsky subgraph` flags, use `/cli-reference` or `goldsky subgraph <cmd> --help` — this skill covers the workflow, not a flag dump.

## Choose an approach first

| You have… | Approach | Path |
|-----------|----------|------|
| A contract + ABI, want a GraphQL API fast, no custom logic | **Instant / no-code subgraph** | Step A |
| Custom entities, relationships, or business logic in handlers | **Code-based subgraph** | Step B |

Both deploy to the same hosted endpoint. Start with instant unless the user needs custom logic.

## Step 0: Verify Authentication

Run `goldsky project list 2>&1`. If not logged in, use `/auth-setup`.

## Step A: Instant / no-code subgraph (from ABI)

Generate and deploy directly from a contract ABI — no AssemblyScript.

```bash
# Interactive wizard (prompts for contract, network, start block, events/calls)
goldsky subgraph init

# Or one-shot from an ABI file
goldsky subgraph deploy my-subgraph/1.0.0 --from-abi ./MyContract.json
```

- The wizard writes a JSON config you can re-deploy and version.
- Enable contract-call indexing with `--enable-call-handlers` (only meaningful with `--from-abi`).
- For richer instant subgraphs (computed fields, `eth_call` enrichment, declared calls), see `references/schema-and-mappings.md` → "Instant subgraph enrichment".

Skip to **Step 5: Deploy**.

## Step B: Code-based subgraph

A code-based subgraph is three files: `subgraph.yaml` (manifest), `schema.graphql` (entities), and `src/` AssemblyScript mappings.

### Step 1: Scaffold

```bash
goldsky subgraph init my-subgraph/1.0.0 --target-path ./my-subgraph
```

Useful flags: `--abi`, `--contract`, `--contract-events`, `--network`, `--start-block`. See `/cli-reference`.

### Step 2: Design the schema

Define the entities your dApp will query in `schema.graphql`. This is the most important design step — get the entity model and types right before writing mappings.

**REQUIRED for any non-trivial schema:** read `references/schema-and-mappings.md` for scalar-type choices (`Bytes` for addresses/hashes, `BigInt` for amounts, `BigDecimal` for prices), `@derivedFrom` relationships, immutable entities, and protocol recipes (ERC-20/721, DEX, lending, governance).

### Step 3: Configure the manifest

Set `specVersion`, the data source(s) (`address`, `abi`, `startBlock`, `network`), and which `eventHandlers` / `callHandlers` / `blockHandlers` map to which functions. Use `templates` for the factory pattern (contracts created at runtime). See `references/schema-and-mappings.md` → "Manifest".

> Use a single `apiVersion` across all data sources — mixed versions fail validation.
> Declared `eth_calls` (a perf win) require `specVersion: 1.2.0`+ — see `references/performance.md`.

### Step 4: Write mappings and build

Write the handler functions in `src/` that turn events into entities. Key idioms (get-or-create, `try_` calls for revert safety, Bytes IDs, `BigInt`/`BigDecimal` math) are in `references/schema-and-mappings.md`. Before deploying, write Matchstick unit tests — see `references/testing.md`.

```bash
goldsky subgraph init my-subgraph/1.0.0 --target-path ./my-subgraph --build
# or build as part of deploy below
```

## Step 5: Deploy

```bash
# From a local code-based build
goldsky subgraph deploy my-subgraph/1.0.0 --path .

# Tag at deploy time so your frontend URL is stable
goldsky subgraph deploy my-subgraph/1.0.0 --path . --tag prod
```

`--path`, `--from-abi`, `--from-ipfs-hash`, and `--from-url` are mutually exclusive — use one.

## Step 6: Endpoints, tags, and webhooks

Once deployed, wire up access. Full details in `references/operations.md`:
- **GraphQL endpoint** — `https://api.goldsky.com/api/public/<project-id>/subgraphs/<name>/<version>/gn`; toggle public/private and use API keys for private.
- **Tags** — pin `prod`/`staging` to a version so the frontend URL never changes on redeploy.
- **Webhooks** — push entity changes (INSERT/UPDATE/DELETE) to an HTTP endpoint.
- **Cross-chain** — deploy per chain, then merge with a Mirror pipeline (`/mirror`).

## Step 7: Verify

```bash
goldsky subgraph list my-subgraph/1.0.0
```

Then query the endpoint, starting with `_meta` to confirm it's indexing:

```graphql
{ _meta { hasIndexingErrors block { number } } }
```

Present a summary (name/version, network, endpoint URL, tag). Point the user to `/subgraph-doctor` if indexing stalls or errors.

## Important Rules

- Subgraphs are **EVM-only**. For Solana/Sui/other non-EVM, use `/turbo-builder` or `/mirror`.
- **Every version is billed separately** (worker + entity storage). Delete old versions you no longer query.
- Redeploying creates a new immutable version — use **tags** so the frontend URL is stable.
- Verify the contract address exists on the target chain and use the correct chain slug (a wrong network indexes blocks that don't exist — the #1 silent failure; see `/subgraph-doctor`).
- Goldsky has a **permanent RPC call cache**, so re-syncs of the same/similar subgraph are much faster.
- Prefer instant subgraphs when there's no custom logic; reach for code-based only when entity modeling or handler logic requires it.

## Reference files

- `references/schema-and-mappings.md` — schema design, scalar types, relationships, manifest, AssemblyScript idioms, instant-subgraph enrichment, protocol recipes
- `references/performance.md` — declared eth_calls, immutable entities, `@derivedFrom`, timeseries/aggregations, pruning, grafting, call cache
- `references/operations.md` — GraphQL endpoints, public/private + API keys, rate limits, tags, webhooks, lifecycle, cross-chain, when-to-use
- `references/testing.md` — Matchstick unit tests, mock library, the Subgraph Linter

## Related

- **`/subgraph-doctor`** — Diagnose a failing, stalled, or won't-deploy subgraph
- **`/subgraph-migrate`** — Migrate an existing subgraph off The Graph
- **`/cli-reference`** — Exhaustive `goldsky subgraph` commands and flags
- **`/turbo-builder`** — Stream raw chain data to a database instead of a GraphQL API
- **`/mirror`** — Sync subgraph entities into your own database (incl. cross-chain merge)
