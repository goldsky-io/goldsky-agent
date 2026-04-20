---
name: compose
description: "Use this skill when the user asks about Goldsky Compose — the offchain-to-onchain TypeScript framework for onchain oracles, keepers, circuit breakers, and cross-chain automation. Triggers on: 'goldsky compose', 'compose.yaml', 'compose deploy/init/dev', 'compose task', 'cron task onchain', 'sponsored gas', 'writeContract from TypeScript', 'build a price oracle', 'resolve prediction market', 'onchain event listener', 'HTTP-triggered task', 'smart wallet'. Also use when the user wants to run TypeScript against EVM chains with managed gas, schedule onchain writes via cron, react to onchain events, or deploy a serverless task with secrets and a smart wallet. For debugging a broken app, use /compose-doctor. For manifest/CLI/API lookups, use /compose-reference. Do NOT trigger on Goldsky Turbo, Mirror, Subgraphs, Edge, or Datasets — those belong to their respective skills."
---

# Goldsky Compose

Goldsky Compose is the offchain-to-onchain framework for high-stakes systems. Write TypeScript **tasks** that run in verifiable sandboxes — triggered by cron, HTTP, or onchain events — with smart wallets, gas sponsorship, and durable collections. Typical use cases: custom price oracles, keepers, circuit breakers, prediction-market resolvers, cross-chain automation, identity/attestation flows, and notifications.

## Boundaries

- Build new Compose apps or explain what Compose is. For debugging a broken app, use `/compose-doctor`.
- Do not serve as a manifest / CLI / API reference. For field syntax, flag lookups, or TaskContext shapes, use `/compose-reference`.
- For `goldsky login`, use `/auth-setup`. For generic secret management, use `/secrets`.

## Mode Detection

Before running commands, check if the `Bash` tool is available:

- **If Bash is available** (CLI mode): use the Walk Me Through It section below to execute commands directly and parse output.
- **If Bash is NOT available** (reference mode): the Quickstart below is enough for most chatbot Q&A. For step-by-step help, output one command at a time and ask the user to paste output back.

## What Compose Does

- Serverless TypeScript runtime for EVM-aware tasks.
- Three trigger types: **cron**, **HTTP**, **onchain_event**.
- **Smart wallets** (managed by Goldsky, gas-sponsored by default) or **BYO EOA** wallets (user-supplied private key).
- Built-in secrets, collections (durable storage), typed contract bindings via codegen.
- `compose dev` for hot-reload local dev; `compose deploy` to ship; `compose logs -f` to tail.

## Out of Scope (for this skill)

- **Deploying the target onchain contract.** Compose writes to contracts that already exist. If the user needs one deployed, direct them to Foundry / Hardhat first and resume here once they have the address + ABI.
- **Sourcing a contract ABI.** The user provides the ABI JSON file; this skill does not fetch from Etherscan / Sourcify.
- **Funding a BYO EOA.** If sponsorship is off, the user must fund the address out-of-band.

## Quickstart

### Install

```bash
curl https://goldsky.com | sh
goldsky login
```

### Scaffold + deploy

```bash
goldsky compose init <app-name>          # scaffolds a Bitcoin-oracle example
cd <app-name>
goldsky compose dev                      # hot-reload local server on :4000
goldsky compose deploy                   # bundle + upload to cloud
goldsky compose status                   # expect RUNNING
goldsky compose logs -f                  # stream logs
```

### Minimal `compose.yaml` + task

```yaml
# compose.yaml
name: my-oracle
api_version: stable
secrets:
  - ORACLE_ADDRESS
tasks:
  - name: hourly_update
    path: src/tasks/hourly-update.ts
    triggers:
      - type: cron
        expression: "0 * * * *"
```

```ts
// src/tasks/hourly-update.ts
import type { TaskContext } from "compose";

export async function main({ evm, env, logEvent }: TaskContext) {
  const wallet = await evm.wallet({ name: "updater" });
  const tx = await wallet.writeContract(
    evm.chains.polygonAmoy,
    env.ORACLE_ADDRESS,
    "update(uint256)",
    [BigInt(Date.now())],
    { confirmations: 3, onReorg: { action: { type: "replay" }, depth: 200 } },
  );
  await logEvent({ code: "updated", message: "ok", data: { hash: tx.hash } });
}
```

## Core Concepts

### Tasks

A task is a TypeScript file exporting `async function main(context, params?)`. Each task declares one or more triggers in `compose.yaml`.

### Triggers

| Type            | Fires on                     | Key config                                                                |
| --------------- | ---------------------------- | ------------------------------------------------------------------------- |
| `cron`          | schedule                     | `expression` (5-field cron)                                               |
| `http`          | HTTP POST to `/tasks/<name>` | `authentication: auth_token \| none`, optional `ip_whitelist`             |
| `onchain_event` | decoded log                  | `network` (snake_case), `contract`, `events` (viem signature strings)     |

### TaskContext

Every task receives `{ env, fetch, callTask, logEvent, evm, collection }`. Secrets flatten into `context.env` — there is no separate `secrets` namespace. See `/compose-reference` for the full API.

### Wallets

Two kinds:

- **Smart wallet (managed)** — `evm.wallet({ name: "updater" })`. Hosted by Goldsky, gas-sponsored by default. Cannot be used in plain local dev — use `compose dev --fork-chains` or switch to a BYO EOA.
- **BYO EOA (private key)** — `evm.wallet({ privateKey: env.MY_KEY, sponsorGas: true })`. **Gas sponsorship is OFF by default** for BYO EOA wallets; opt in explicitly.

### Secrets & env

List names in the manifest's `secrets:` array, set values with `goldsky compose secret set --name X --value Y` (or `compose secret sync` to upload `.env`). Values flatten into `context.env` at runtime. Names must be SCREAMING_SNAKE_CASE.

### Gas sponsorship

Bundler fallback: Alchemy → Pimlico → Gelato. Broad EVM coverage (mainnet + testnet); see `/compose-reference` for the chain list and caveats.

### Dashboard

Every deployed app has a dashboard at `https://app.goldsky.com/<project_id>/dashboard/compose/<app-name>`.

## Capability Tour

Inline worked examples. Start with **Cron → writeContract** if you don't know which applies.

### Cron → writeContract (the scaffold default)

Exactly the minimal task above — a cron task that writes to a contract every hour, with `onReorg: replay` for safety.

### HTTP task with auth_token

```yaml
# compose.yaml (task entry)
- name: manual_fire
  path: src/tasks/manual-fire.ts
  triggers:
    - type: http
      authentication: auth_token
```

```ts
// src/tasks/manual-fire.ts
import type { TaskContext } from "compose";

export async function main({ logEvent }: TaskContext, params: { amount: number }) {
  await logEvent({ code: "fired", message: "manual", data: params });
  return { ok: true, received: params.amount };
}
```

Invoke: `curl -X POST -H "Authorization: Bearer $TOKEN" -d '{"amount": 42}' https://<app-url>/tasks/manual_fire`.

### Onchain event listener

```yaml
- name: on_transfer
  path: src/tasks/on-transfer.ts
  triggers:
    - type: onchain_event
      network: polygon_amoy
      contract: "0xYourContract"
      events:
        - "Transfer(address,address,uint256)"
```

```ts
import type { TaskContext } from "compose";

export async function main(
  { evm, logEvent }: TaskContext,
  params: { log: { topics: string[]; data: string; address: string } },
) {
  const decoded = await evm.decodeEventLog(
    [{ type: "event", name: "Transfer", inputs: [/* ABI inputs */] }],
    params.log,
  );
  await logEvent({ code: "transfer", message: "seen", data: decoded });
}
```

### Smart wallet + sponsored writeContract

```ts
const wallet = await evm.wallet({ name: "my-oracle" }); // sponsorGas defaults TRUE
const tx = await wallet.writeContract(
  evm.chains.base,
  env.FEED_ADDRESS,
  "setPrice(uint256)",
  [1234n],
);
```

### BYO EOA with sponsored gas (opt-in)

```ts
const wallet = await evm.wallet({
  privateKey: env.MY_KEY,
  sponsorGas: true, // MUST opt in; defaults FALSE
});
```

### Durable storage (collection)

```ts
const runs = await collection<{ id: string; ts: number }>("runs");
await runs.setById("latest", { id: "latest", ts: Date.now() });
const recent = await runs.findOne({ ts: { $gt: Date.now() - 86_400_000 } });
```

### Typed contracts via codegen

Drop an ABI into `src/contracts/Oracle.json`. After `goldsky compose codegen` (or any `init`/`dev`/`deploy`), the contract is available as `evm.contracts.Oracle`. Full workflow in `/compose-reference`.

## Walk Me Through It

Only activate when Bash is available.

### Step 1 — Verify auth

`goldsky project list 2>&1`. If not logged in, use `/auth-setup`.

### Step 2 — Derive first, ask only the ambiguous

From the user's natural-language prompt, **derive** as many of these as possible before asking:

- **Trigger type** — "every 5 minutes" → cron; "on each Transfer" → onchain_event; "when I call it" → http.
- **Chain** — named (`polygonAmoy`, `base`) → use it; "testnet" with no name → ask.
- **Read vs write** — "track", "index", "notify" → read; "update", "set", "submit" → write.
- **Wallet** — write + sponsored gas → smart wallet (default); user supplied a PK → BYO EOA with `sponsorGas: true`.
- **Secrets** — any external API key or contract address → needs a secret entry.
- **`api_version`** — default to `stable` unless user asks otherwise.

Only ask the user for fields you couldn't derive.

### Step 3 — Scaffold

`goldsky compose init <name>`. Inspect the scaffold to see the canonical file layout.

### Step 4 — Edit the manifest

Replace the scaffold's task block with the derived trigger + secret list. Use the YAML snippets from the Capability Tour above.

### Step 5 — Write the task

Replace the scaffold's task file with logic derived from the prompt. Use the capability-tour snippet for the chosen trigger as the starting point.

### Step 6 — Wire secrets and wallets

- Every name in `compose.yaml`'s `secrets:` → `goldsky compose secret set --name X --value Y` (or add to `.env` + `compose secret sync`).
- Smart wallet → `goldsky compose wallet create --name <name>`. Then `wallet list` to get the address and share with the user (they may need to grant it onchain permissions on the target contract).
- BYO EOA → add the private key to `.env` (SCREAMING_SNAKE_CASE name), reference via `env.X` in the task.

### Step 7 — Local dev

`goldsky compose dev`. Smart wallets require `--fork-chains` locally; use a BYO EOA if the user wants to test against a live testnet. For HTTP tasks: `goldsky compose callTask <name> '<json>'` in another terminal.

### Step 8 — Deploy

`goldsky compose deploy`. Expect progress: "Building Dedicated app database…" → "Deploying app…" → "Provisioning infra…" (can take a minute or two on first deploy).

### Step 9 — Verify

```bash
goldsky compose status --json     # expect .status == "RUNNING"
goldsky compose logs -f           # expect app-specific log lines
```

Share the dashboard URL: `https://app.goldsky.com/<project_id>/dashboard/compose/<app-name>`.

## Important Rules

- **Smart wallets don't work in plain `compose dev`** — use `--fork-chains` or switch to a BYO EOA for local iteration.
- **BYO EOA gas sponsorship defaults to FALSE** — opt in explicitly with `sponsorGas: true`.
- **Cloud secrets are not synced from `.env` automatically.** Run `compose secret sync` or `compose deploy --sync-env`.
- **Secret names must be SCREAMING_SNAKE_CASE.**
- **`api_version` is required for deploy.** Default to `stable`.

## Related

- **`/compose-doctor`** — Diagnose and fix broken Compose apps.
- **`/compose-reference`** — Manifest, CLI, TaskContext API, wallets, gas sponsorship, codegen.
- **`/auth-setup`** — `goldsky login` walkthrough.
- **`/secrets`** — Generic secret management.
