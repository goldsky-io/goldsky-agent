<!--
  Entry point for AI coding agents. Kept in sync with SKILLS.md (the canonical
  skill index) by hand — if you add/rename/remove a skill, update both.
  Humans should read README.md instead.
-->

# AGENTS.md — Goldsky Agent

Guide for AI coding agents (Devin, Codex, Cursor, Amp, Claude Code, and anything else that reads `AGENTS.md`). This repo is a **skill pack** for building, deploying, and debugging on Goldsky — Turbo pipelines, Mirror pipelines, Subgraphs, Compose, and Edge RPC. Each skill is a self-contained folder of step-by-step instructions plus reference material.

## How to use these skills

Some hosts (Claude Code, Cursor) auto-discover skills and trigger them from each skill's `description`. **If your runtime has no "skills" feature, use them manually — they are just Markdown:**

1. Identify the task (build a pipeline, fix a broken one, write a transform, deploy/repair a subgraph, build a Compose app…).
2. Open the matching `skills/<name>/SKILL.md` (routing table below; full index in [`SKILLS.md`](./SKILLS.md)).
3. Follow it. A `SKILL.md` points into deeper files under `skills/<name>/references/` and `skills/<name>/templates/` — read those when it tells you to.
4. For **reference lookups** (CLI flags, YAML fields, dataset names, error codes), query the Goldsky **docs MCP** at `https://docs.goldsky.com/mcp` rather than guessing. Every published doc is also in `https://docs.goldsky.com/llms.txt`.

Each `SKILL.md` opens with a `description:` in its frontmatter stating what it covers and when to use it — scan those to route.

## Skill routing

| If the task is… | Use skill |
| --- | --- |
| Build/deploy a new Turbo pipeline (chain → dataset → transforms → sink) | `turbo-builder` |
| A Turbo pipeline is broken / not getting data / output looks wrong | `turbo-doctor` |
| Turbo YAML syntax, sources/sinks, architecture & sizing decisions | `turbo-pipelines` |
| Write a SQL / TypeScript / dynamic-table transform (incl. EVM & Solana decoding) | `turbo-transforms` |
| Pause / restart / delete a pipeline; interpret a pipeline error | `turbo-operations` |
| Sync a subgraph entity source to a DB; Mirror vs Turbo | `mirror` |
| A Mirror pipeline is failing / stuck / terminated | `mirror-doctor` |
| Author / build / deploy a subgraph; schema, mappings, manifest | `subgraph-builder` |
| A subgraph stopped syncing / won't deploy / errors | `subgraph-doctor` |
| Migrate a subgraph off The Graph | `subgraph-migrate` |
| Build a Compose app (oracle / keeper / automation) in TypeScript | `compose` |
| A Compose app is crashlooping / not processing tasks | `compose-doctor` |
| `compose.yaml` fields, `goldsky compose` flags, `TaskContext` API | `compose-reference` |
| Worked example: onchain BTC/USD price oracle | `compose-bitcoin-oracle` |
| Worked example: onchain verifiable randomness (VRF) | `compose-vrf` |
| Get a fast, reliable managed RPC endpoint; RPC error codes | `edge` |
| Find the right dataset name / chain prefix | `datasets` |
| Store credentials for a sink (Postgres, ClickHouse, Kafka…) | `secrets` |
| Install the CLI / log in / switch projects / fix `unauthorized` | `auth-setup` |

Canonical list with descriptions: [`SKILLS.md`](./SKILLS.md).

## Gotchas agents get wrong — read before generating code

- **A green validate is not proof it works.** After generating a pipeline, run `goldsky turbo validate` before presenting it — but validation checks YAML/SQL *shape*, not *correctness* (right addresses, real event signatures, sane volume). Don't claim it works on the strength of validation alone.
- **Never invent onchain identifiers.** EVM contract addresses (`0x…`), Solana program IDs, and token mints (base58) must come from the user or a real lookup — **never from memory**. A guessed address validates and deploys fine but silently matches nothing (or the wrong thing). If you don't have a verified one, ask the user to paste it.
- **Solana decoding is not base58.** Instruction `data` is base58-encoded *bytes* — base58-decoding it gives you raw bytes, **not** the decoded instruction. Decode by passing the base58 `data` directly to an IDL decoder (`_gs_decode_instruction_data(idl, data)`) or a program-specific decoder (`_gs_solana_decode_*(data, accounts)`). See `skills/turbo-transforms/references/solana-patterns.md`.
- **Prefer Turbo over Mirror** for new pipelines. Reach for Mirror only when you specifically need a subgraph entity source — the one thing Turbo can't do.

## Editing skills in THIS repo (opening a PR here)

If your task is to change anything under `skills/` in this repo (not just *use* a skill), do this in the same PR — CI enforces it:

1. **Bump the plugin version:** run **`npm run bump`** — patch by default (`npm run bump -- minor` or `npm run bump -- major` for larger changes). It bumps and syncs the version across `package.json`, `.claude-plugin/plugin.json`, `.cursor-plugin/plugin.json`, and `.claude-plugin/marketplace.json`. **Commit those four files with your skill change.** Claude Code and Cursor plugin users only receive updates when the version changes — skip this and they stay on the old skills. Never hand-edit the versions; always use `npm run bump` so all four stay in sync. The `require-version-bump` check fails the PR if you don't.
2. **If you add/rename/remove a skill,** also update [`SKILLS.md`](./SKILLS.md) and the routing table above.

## Install (for agents that support it)

```bash
# Copies skills into your project for 30+ supported agents:
npx skills add goldsky-io/goldsky-agent

# From the docs site — also exposes skills as MCP resources and at /.well-known/skills:
npx skills add https://docs.goldsky.com
```

If your agent supports MCP, connect the Goldsky docs MCP directly: `https://docs.goldsky.com/mcp`.

## Links

- Canonical skill index: [`SKILLS.md`](./SKILLS.md)
- Human-facing overview: [`README.md`](./README.md)
- Docs: https://docs.goldsky.com — MCP: `https://docs.goldsky.com/mcp` — `llms.txt`: https://docs.goldsky.com/llms.txt
