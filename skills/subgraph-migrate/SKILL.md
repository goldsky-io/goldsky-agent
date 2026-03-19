---
name: subgraph-migrate
description: "Migrate an existing subgraph to Goldsky from TheGraph, Alchemy, or any other subgraph hosting provider. Use when the user says 'migrate my subgraph', 'move from TheGraph to Goldsky', 'I have an IPFS hash for my subgraph', 'deploy from TheGraph explorer', 'migrate from Alchemy', 'migrate from Satsuma', or 'I want to run my existing subgraph on Goldsky'. Covers one-step IPFS migration from TheGraph, Alchemy-to-Goldsky workflow differences, tag migration, graft handling, and post-migration verification. Do NOT use for creating new subgraphs from scratch (use /subgraph-builder), diagnosing broken subgraphs (use /subgraph-doctor), or managing existing Goldsky subgraphs (use /subgraph-lifecycle)."
---

# Subgraph Migration

## Boundaries

- Migrate EXISTING subgraphs from other hosts to Goldsky.
- Do not build new subgraphs from scratch — that belongs to `/subgraph-builder`.
- Do not diagnose broken subgraphs — use `/subgraph-doctor`.
- For post-migration tag and lifecycle management, use `/subgraph-lifecycle`.

Guide the user through migrating their subgraph to Goldsky with zero downtime.

## Mode Detection

Before running any commands, check if you have the `Bash` tool available:

- **If Bash is available** (CLI mode): Execute commands directly.
- **If Bash is NOT available** (reference mode): Provide copy-paste commands.

## Migration Workflow

### Step 1: Verify Authentication

Run `goldsky project list 2>&1` to check login status.

- **If logged in:** Note the current project and continue.
- **If not logged in:** Use the `/auth-setup` skill for guidance.

### Step 2: Determine Source Platform

Ask the user where their subgraph is currently hosted:

| Source | Migration Path |
| ------ | -------------- |
| TheGraph (decentralized network) | IPFS hash migration |
| TheGraph (hosted service) | IPFS hash or URL migration |
| Alchemy / Satsuma | Source code deployment (`--path .`) |
| Other GraphQL endpoint | URL migration (`--from-url`) |
| Local source code | Source code deployment (`--path .`) |

### Step 3: Execute Migration

#### Path A: TheGraph via IPFS Hash (Most Common)

**Get the IPFS hash** — two ways:

1. From TheGraph Explorer UI — find the deployment hash on the subgraph's page
2. From any GraphQL endpoint — query:
   ```graphql
   {
     _meta {
       deployment
     }
   }
   ```

**Deploy to Goldsky:**

```bash
goldsky subgraph deploy <name>/<version> --from-ipfs-hash <ipfs-hash>
```

Example:
```bash
goldsky subgraph deploy uniswap-v3/1.0.0 --from-ipfs-hash QmXyz123abc456
```

**Optional flags:**
- `--tag prod` — immediately tag for a stable endpoint
- `--start-block <N>` — override the start block
- `--remove-graft` — remove graft dependencies (recommended for clean migration)

#### Path B: URL Migration

For subgraphs accessible via a public GraphQL endpoint:

```bash
goldsky subgraph deploy <name>/<version> --from-url <graphql-endpoint>
```

#### Path C: Alchemy / Source Code Migration

Alchemy subgraphs can be migrated two ways:

**Option 1: Via IPFS hash (try this first):**
```bash
goldsky subgraph deploy <name>/<version> --from-ipfs-hash <hash> --ipfs-gateway https://ipfs.satsuma.xyz
```

> **Note:** Use the Satsuma IPFS gateway (`https://ipfs.satsuma.xyz`) for Alchemy subgraphs. The default TheGraph gateway won't resolve Alchemy hashes. This method does not always work — if it fails, use Option 2.

**Option 2: From source code:**
1. Ensure you have the subgraph source code locally (subgraph.yaml, schema.graphql, mappings)
2. Deploy:
   ```bash
   goldsky subgraph deploy <name>/<version> --path .
   ```

Alchemy and Goldsky implement tags differently. See `/subgraph-lifecycle` for Goldsky tag management.

### Step 4: Handle Grafts

If the source subgraph uses grafting:

- **Option A:** Remove the graft and index from scratch:
  ```bash
  goldsky subgraph deploy <name>/<version> --from-ipfs-hash <hash> --remove-graft
  ```

- **Option B:** Graft from an existing Goldsky subgraph:
  ```bash
  goldsky subgraph deploy <name>/<version> --from-ipfs-hash <hash> \
    --graft-from existing-subgraph/1.0.0 \
    --start-block <graft-block>
  ```

> **Recommendation:** Use `--remove-graft` for clean migrations. The subgraph will re-index from its defined start block.

### Step 5: Verify Deployment

```bash
goldsky subgraph list
```

Check:
- Subgraph appears in the list
- Status shows "Indexing" or "Synced"
- GraphQL endpoint is accessible

Test a query against the new endpoint:
```graphql
{
  _meta {
    block {
      number
    }
  }
}
```

### Step 6: Set Up Tags for Zero-Downtime Swap

Create a tag so your frontend can switch to Goldsky without changing URLs:

```bash
goldsky subgraph tag create <name>/<version> --tag prod
```

The tagged endpoint becomes your stable URL. See `/subgraph-lifecycle` for tag management.

### Step 7: Present Migration Summary

```
## Migration Complete

**Source:** [TheGraph / Alchemy / Other]
**Name:** [name/version]
**Status:** [Indexing / Synced]

**Endpoints:**
- Versioned: [versioned endpoint URL]
- Tagged (prod): [tagged endpoint URL]

**What Goldsky adds:**
- 99.9%+ uptime with load-balanced RPC
- Up to 6x faster indexing
- Tags for zero-downtime version swaps
- Built-in webhooks for notifications
- Auto-recovery from data consistency issues
- 24/7 monitoring with on-call support

**Next steps:**
- Update frontend to use the tagged endpoint
- Set up webhooks if needed: `/subgraph-lifecycle`
- Monitor sync progress: `goldsky subgraph list`
- Delete old subgraph on previous host once fully migrated
```

## Important Rules

- Always use `--remove-graft` unless the user specifically needs to graft from a Goldsky subgraph
- IPFS hash migration is the simplest path from TheGraph — always try this first
- If IPFS download times out (524 error), retry or try a different gateway with `--ipfs-gateway`
- Subgraph names on Goldsky must start with a letter and contain only letters, numbers, underscores, and hyphens
- Multiple chains require separate subgraph deployments
- Migration from TheGraph is a drop-in replacement — same GraphQL API, same queries work

## Related

- **`/subgraph-builder`** — Build new subgraphs from scratch
- **`/subgraph-lifecycle`** — Tag management and zero-downtime upgrades
- **`/subgraph-config`** — CLI flags and configuration reference
- **`/subgraph-doctor`** — Diagnose migration issues
- **`/auth-setup`** — CLI installation and authentication
