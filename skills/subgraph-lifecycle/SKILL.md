---
name: subgraph-lifecycle
description: "Subgraph state management, tags, and webhooks — pause, start, delete, tag, update, and webhook commands with their rules and behaviors. Use this skill when the user asks: how do I pause a subgraph, how do I resume/start a paused subgraph, how do I delete a subgraph version, how do I create or manage tags for zero-downtime version swaps, how do I toggle public/private GraphQL endpoints, how do I create a webhook for subgraph entity changes, how do I list or delete webhooks, what entities can I hook into, or how do I do a zero-downtime subgraph upgrade. For actively diagnosing why a subgraph is broken, use /subgraph-doctor instead. For deploying new subgraphs, use /subgraph-builder."
---

# Subgraph Lifecycle Reference

CLI commands for managing subgraph state, tags, endpoints, and webhooks. For interactive subgraph troubleshooting, use `/subgraph-doctor` instead.

---

## Quick Reference

| Action | Command |
| ------ | ------- |
| List all subgraphs | `goldsky subgraph list` |
| List specific subgraph | `goldsky subgraph list name/version` |
| Pause subgraph | `goldsky subgraph pause name/version` |
| Start/resume subgraph | `goldsky subgraph start name/version` |
| Delete subgraph | `goldsky subgraph delete name/version` |
| View logs | `goldsky subgraph log name/version` |
| Update endpoint settings | `goldsky subgraph update name/version` |

---

## Subgraph States

| State | Description |
| ----- | ----------- |
| Indexing | Subgraph is actively syncing and processing blocks |
| Synced | Subgraph is caught up to the chain tip and indexing new blocks in real time |
| Paused | Subgraph was manually paused or auto-paused due to stalling |
| Error | Subgraph encountered a fatal error during indexing |

---

## Lifecycle Commands

### Pause

```bash
goldsky subgraph pause name/version
```

Stops the subgraph from indexing. Useful for:
- Reducing costs while not actively querying
- Pausing during maintenance
- Investigating issues without the subgraph continuing to index bad data

### Start / Resume

```bash
goldsky subgraph start name/version
```

Resumes a paused subgraph. It picks up from where it left off.

### Delete

```bash
goldsky subgraph delete name/version
```

Permanently removes a subgraph version. **This is irreversible** — the subgraph data, GraphQL endpoint, and indexing progress are all deleted.

**Before deleting:**
- Move any tags pointing to this version to another version first
- Ensure no frontend code depends on this specific version's endpoint

### Update

```bash
goldsky subgraph update name/version --public-endpoint true
goldsky subgraph update name/version --private-endpoint true
```

Toggle public/private endpoint visibility. By default, subgraphs have private endpoints that require an API key.

---

## Tag Management

Tags are aliases that point to a specific subgraph version. They enable zero-downtime upgrades by keeping a stable GraphQL endpoint URL while swapping the underlying version.

### Create a Tag

```bash
goldsky subgraph tag create name/version --tag prod
```

This creates (or moves) the `prod` tag to point to `name/version`. The tagged GraphQL endpoint uses the tag name instead of the version number.

### Delete a Tag

```bash
goldsky subgraph tag delete name/version --tag prod
```

Removes the tag association from this version.

### Zero-Downtime Upgrade Pattern

1. Deploy new version:
   ```bash
   goldsky subgraph deploy my-subgraph/2.0.0 --path .
   ```

2. Wait for it to sync (check with `goldsky subgraph list`).

3. Move the tag to the new version:
   ```bash
   goldsky subgraph tag create my-subgraph/2.0.0 --tag prod
   ```

4. Verify the tagged endpoint is serving data from v2:
   - Query `{ _meta { deployment } }` to confirm

5. Delete the old version (optional):
   ```bash
   goldsky subgraph delete my-subgraph/1.0.0
   ```

**Key points:**
- Frontend code uses the tagged endpoint URL, which never changes
- Moving a tag is instant — no downtime, no stale data
- You can have multiple tags (e.g., `prod`, `staging`, `dev`)

### GraphQL Endpoint Formats

| Type | Format |
| ---- | ------ |
| Versioned | `.../subgraphs/name/1.0.0/gn` |
| Tagged | `.../subgraphs/name/prod/gn` |

---

## Webhooks

Subgraph webhooks send HTTP POST requests to your endpoint whenever a subgraph entity changes. Use for notifications, backend updates, or real-time reactions to indexed events.

> **For guaranteed data delivery to a database**, use Mirror pipelines with a subgraph source instead of webhooks. Webhooks are best for notifications and lightweight integrations.

### Webhook Commands

| Action | Command |
| ------ | ------- |
| Create webhook | `goldsky subgraph webhook create name/version` |
| List all webhooks | `goldsky subgraph webhook list` |
| Delete webhook | `goldsky subgraph webhook delete <webhook-name>` |
| List available entities | `goldsky subgraph webhook list-entities name/version` |

### Create a Webhook

```bash
goldsky subgraph webhook create name/version \
  --name my-webhook \
  --url https://my-server.com/webhook \
  --entity Transfer
```

| Flag | Required | Description |
| ---- | -------- | ----------- |
| `--name` | Yes | Unique name for this webhook |
| `--url` | Yes | HTTP endpoint to receive POST requests |
| `--entity` | Yes | Entity name to watch (from `list-entities`) |
| `--secret` | No | Secret for request verification (auto-generated if omitted) |

### List Webhook Entities

Before creating a webhook, check which entities are available:

```bash
goldsky subgraph webhook list-entities name/version
```

This returns all entity types defined in the subgraph's schema.

### Delete a Webhook

```bash
goldsky subgraph webhook delete my-webhook
# Or force without confirmation:
goldsky subgraph webhook delete my-webhook --force
```

### Webhook Payload

Webhooks send a JSON POST request to your URL for every entity change. The payload includes the entity data and metadata. Your endpoint should return a `200` status code to acknowledge receipt.

---

## Common Patterns

### Version Promotion

```bash
# Deploy to staging
goldsky subgraph deploy my-subgraph/2.0.0 --path . --tag staging

# Test via staging endpoint
# ...

# Promote to production
goldsky subgraph tag create my-subgraph/2.0.0 --tag prod
```

### Rollback

```bash
# Move tag back to previous version
goldsky subgraph tag create my-subgraph/1.0.0 --tag prod
```

### Cleanup Old Versions

```bash
# List all versions
goldsky subgraph list my-subgraph

# Delete old versions (ensure no tags point to them)
goldsky subgraph delete my-subgraph/1.0.0
```

---

## Related

- **`/subgraph-builder`** — Deploy new subgraphs step-by-step
- **`/subgraph-doctor`** — Diagnose and fix subgraph issues
- **`/subgraph-config`** — Configuration reference and CLI flags
- **`/subgraph-monitor-debug`** — Error patterns and log analysis
