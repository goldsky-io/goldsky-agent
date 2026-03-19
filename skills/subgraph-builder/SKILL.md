---
name: subgraph-builder
description: "Use this skill when the user wants to deploy, create, or set up a new Goldsky subgraph from scratch. Triggers when someone wants to index a smart contract's events, create a GraphQL API for blockchain data, or asks to be walked through subgraph deployment. Also triggers for phrases like 'create a subgraph', 'index this contract', 'deploy a no-code subgraph', 'set up an instant subgraph', 'I have an ABI and want a GraphQL endpoint', or 'track events on chain X'. Covers choosing the deployment method (no-code wizard, low-code JSON config, or source code), gathering contract details, generating configuration, and deploying. Do NOT use for migrating existing subgraphs from TheGraph or Alchemy (use /subgraph-migrate), diagnosing broken subgraphs (use /subgraph-doctor), looking up CLI syntax or JSON config fields (use /subgraph-config), or managing webhooks and tags (use /subgraph-lifecycle)."
---

# Subgraph Builder

## Boundaries

- Build and deploy NEW subgraphs. Do not diagnose broken subgraphs — that belongs to `/subgraph-doctor`.
- Do not serve as a config reference. If the user only needs to look up a field or syntax, use `/subgraph-config`.
- For migrating existing subgraphs from TheGraph/Alchemy, use `/subgraph-migrate`.
- For tag management and webhooks after deployment, use `/subgraph-lifecycle`.

Walk the user through deploying a complete subgraph from scratch, step by step.

## Mode Detection

Before running any commands, check if you have the `Bash` tool available:

- **If Bash is available** (CLI mode): Execute commands, generate configs, and deploy directly.
- **If Bash is NOT available** (reference mode): Generate the configuration and provide copy-paste instructions for the user to deploy manually.

## Builder Workflow

### Step 1: Verify Authentication

Run `goldsky project list 2>&1` to check login status.

- **If logged in:** Note the current project and continue.
- **If not logged in:** Use the `/auth-setup` skill for guidance.

### Step 2: Understand the Goal

Ask the user what they want to index. Good questions:

- What blockchain/chain? (Ethereum, Base, Polygon, Arbitrum, etc.)
- What contract(s)? (address, ABI)
- What events? (transfers, swaps, mints, all events?)
- Do they need enrichments? (eth_call to read on-chain state)
- What start block? (genesis, recent, specific block)

If the user already described their goal, extract answers from their description.

### Step 3: Choose Deployment Method

Present the options and recommend based on their needs:

| Scenario | Method | Why |
| -------- | ------ | --- |
| Quick exploration, single contract | **No-code wizard** | Zero config, ABI auto-fetched from explorer |
| Multiple contracts, enrichments, custom schema | **Low-code JSON** | More control without writing mappings |
| Custom mapping logic, complex entity relationships | **Source code** | Full subgraph development with AssemblyScript |
| Existing subgraph on TheGraph/Alchemy | *(redirect to `/subgraph-migrate`)* | Different workflow |

### Step 4: Gather Details

Based on the chosen method:

**No-code wizard:**
- Contract address
- Chain
- Start block (optional)
- Which events to index (optional — defaults to all)

**Low-code JSON:**
- ABI file(s) — user provides or we help them get it from a block explorer
- Contract address(es)
- Chain slug(s) — use `/subgraph-config` for the correct slug
- Start block(s)
- Enrichments needed?

**Source code:**
- Existing subgraph.yaml, schema.graphql, and mappings
- Or scaffold from scratch with `goldsky subgraph init`

### Step 5: Generate Configuration

**No-code wizard path:**

```bash
goldsky subgraph deploy <name>/<version> --from-abi \
  --contract <address> \
  --network <chain-slug> \
  --start-block <block>
```

If sufficient flags are provided, the wizard runs in non-interactive mode. Otherwise, it prompts interactively.

**Low-code JSON path:**

Generate the instant subgraph config:

```json
{
  "version": "1",
  "abis": {
    "<ContractName>": {
      "path": "./<abi-file>.json"
    }
  },
  "instances": [
    {
      "abi": "<ContractName>",
      "address": "<contract-address>",
      "chain": "<chain-slug>",
      "startBlock": <block-number>
    }
  ]
}
```

Save to a file (e.g., `subgraph-config.json`).

**Source code path:**

Scaffold with:
```bash
goldsky subgraph init <name>/<version> \
  --abi ./abi.json \
  --contract <address> \
  --network <chain-slug> \
  --start-block <block> \
  --build --deploy
```

Or guide through manual subgraph.yaml, schema.graphql, and mapping creation.

### Step 6: Deploy

**No-code (interactive wizard):**
```bash
goldsky subgraph deploy <name>/<version> --from-abi
```

**Low-code (from config file):**
```bash
goldsky subgraph deploy <name>/<version> --from-abi subgraph-config.json
```

**Source code:**
```bash
goldsky subgraph deploy <name>/<version> --path .
```

Optionally tag on deployment:
```bash
goldsky subgraph deploy <name>/<version> --from-abi config.json --tag prod
```

### Step 7: Verify

After deployment:

```bash
goldsky subgraph list
```

Check that the subgraph appears and note its sync status. The GraphQL endpoint URL will be displayed after deployment.

### Step 8: Present Summary

```
## Subgraph Deployed

**Name:** [name/version]
**Chain:** [chain]
**Contract:** [address]
**Method:** [no-code / low-code / source]
**GraphQL Endpoint:** [endpoint URL]

**Next steps:**
- Query your data at the GraphQL endpoint
- Set up tags for zero-downtime upgrades: `/subgraph-lifecycle`
- Add webhooks for real-time notifications: `/subgraph-lifecycle`
- Monitor sync progress: `goldsky subgraph list`
- Check logs if issues arise: `goldsky subgraph log name/version`
- Use `/subgraph-doctor` if you run into problems
```

## Important Rules

- Always verify the chain slug is correct for subgraphs. Subgraph slugs differ from Turbo dataset prefixes (e.g., `mainnet` not `ethereum`, `arbitrum-one` not `arbitrum`). See `/subgraph-config` for the full list.
- Always confirm the contract address and chain with the user before deploying.
- For the no-code wizard, prefer providing flags (`--contract`, `--network`, `--start-block`) so the user can see the full command.
- Subgraph names must start with a letter and contain only letters, numbers, underscores, and hyphens.
- Versions can be any string starting with a letter or number (e.g., `1.0.0`, `v2-beta`).
- If the user wants to index the same contract on multiple chains, each chain creates a separate subgraph.

## Starter Templates

> **Template files are available in the `templates/` folder.** These are instant subgraph JSON configs for common patterns.

| Template | Description |
| -------- | ----------- |
| `instant-single-contract.json` | Minimal single-contract config |
| `instant-multi-contract.json` | Multiple contracts with different ABIs |
| `instant-multi-chain.json` | Same contract across multiple chains |
| `instant-with-enrichments.json` | Config with eth_call enrichments |

## Related

- **`/subgraph-architecture`** — High-level design decisions (subgraph vs pipeline, cross-chain strategies)
- **`/subgraph-config`** — Configuration reference and CLI flags
- **`/subgraph-doctor`** — Diagnose and fix subgraph issues
- **`/subgraph-migrate`** — Migrate from TheGraph or Alchemy
- **`/subgraph-lifecycle`** — Tags, webhooks, pause/start/delete
- **`/auth-setup`** — CLI installation and authentication
