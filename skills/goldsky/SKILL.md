---
name: goldsky
description: "Goldsky entry point and reference router. Trigger for cross-cutting Goldsky reference questions (dataset names, sink/secret fields, CLI flags, SQL functions, chain prefixes, pipeline states) and when a docs/reference lookup is failing or the right tool is unclear. Do NOT trigger when the task maps to a specific recipe — building or fixing a Turbo/Mirror pipeline, building or fixing a subgraph, building or fixing a Compose app, or CLI auth — use that skill instead."
---

# Goldsky

## Reference questions → the docs
For anything factual (dataset names, sink/secret fields, CLI flags, SQL
functions, chain prefixes, pipeline states), search the **Goldsky docs MCP**,
or browse https://docs.goldsky.com. The docs are the source of truth.

**No docs MCP available?** Install it (one-time):
https://docs.goldsky.com/mcp-server

## Task → recipe routing
| The user wants to… | Use skill |
| --- | --- |
| Build a Turbo pipeline | `turbo-builder` |
| Fix a broken Turbo pipeline | `turbo-doctor` |
| Write a SQL/TS/dynamic transform | `turbo-transforms` |
| Fix a broken Mirror pipeline | `mirror-doctor` |
| Build a Compose app | `compose` |
| Fix a broken Compose app | `compose-doctor` |
| Build/deploy a subgraph | `subgraph-builder` |
| Fix a broken subgraph | `subgraph-doctor` |
| Migrate a subgraph from The Graph | `subgraph-migrate` |
| Set up the CLI / log in | `auth-setup` |
| Get a managed RPC endpoint | see https://docs.goldsky.com/edge-rpc |
