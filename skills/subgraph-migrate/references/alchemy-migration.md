# Alchemy / Satsuma Migration Guide

## Overview

Migrating from Alchemy (formerly Satsuma) to Goldsky involves deploying your subgraph source code and migrating your tag workflow.

## Key Differences

| Feature | Alchemy | Goldsky |
| ------- | ------- | ------- |
| Deployment | `graph deploy` | `goldsky subgraph deploy name/version --path .` |
| Versioning | Version labels | Explicit `name/version` format |
| Tags | Managed via UI | CLI: `goldsky subgraph tag create name/version --tag prod` |
| Webhooks | Not built-in | Built-in: `goldsky subgraph webhook create` |
| Grafting | Standard subgraph grafting | Same + `--graft-from` flag for Goldsky-native grafting |

## Migration Steps

### 1. Prepare Source Code

Ensure you have the complete subgraph source locally:
- `subgraph.yaml` — manifest
- `schema.graphql` — entity definitions
- `src/` — AssemblyScript mappings
- `abis/` — contract ABIs

### 2. Deploy to Goldsky

```bash
goldsky subgraph deploy my-subgraph/1.0.0 --path .
```

### 3. Migrate Tags

Goldsky tags work similarly to Alchemy's version labels:

```bash
# Create a prod tag pointing to your version
goldsky subgraph tag create my-subgraph/1.0.0 --tag prod
```

The tagged endpoint becomes your stable URL for frontend integration.

### 4. Update Frontend

Replace your Alchemy GraphQL endpoint with the Goldsky tagged endpoint:
- Old: `https://subgraph.satsuma-prod.com/<org>/my-subgraph/api`
- New: `https://api.goldsky.com/api/public/<project-hash>/subgraphs/my-subgraph/prod/gn`

### 5. Zero-Downtime Version Upgrades

When deploying a new version:

```bash
# Deploy new version
goldsky subgraph deploy my-subgraph/2.0.0 --path .

# Wait for it to sync, then move the tag
goldsky subgraph tag create my-subgraph/2.0.0 --tag prod

# Clean up old version
goldsky subgraph delete my-subgraph/1.0.0
```

## Pre-Migrated Subgraphs

If Goldsky pre-migrated your subgraphs from Alchemy:
- They may already be live and fully synced
- Some may be in a **Paused** state if detected as inactive
- Resume paused subgraphs: `goldsky subgraph start name/version`

## Monitoring After Migration

- Check status: `goldsky subgraph list`
- View logs: `goldsky subgraph log name/version`
- Dashboard: Navigate to app.goldsky.com for real-time indexing progress, query metrics, and error logs
