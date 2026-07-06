---
name: compose
description: "Always load this skill whenever the conversation is about Goldsky Compose (the offchain-to-onchain TypeScript framework for oracles, keepers, circuit breakers, and cross-chain automation) — no matter what the user wants to do with it. That includes: asking what Compose is, its docs, pricing, functionality, or limits; building, deploying, or iterating on an app; wiring cron / HTTP / onchain-event triggers, smart wallets, gas sponsorship, secrets, or collections; deploying a worked example; or debugging an existing app. This is the entry point for the Compose skill family — load it FIRST, then pull in the others it points to: /compose-reference for concrete manifest/CLI/API rules, a worked-example template (compose-bitcoin-oracle, compose-vrf, compose-dividend-distribution, compose-compliance-oracle) when the user wants that specific app, and /compose-doctor for hands-on debugging. Do NOT load for Goldsky Turbo, Mirror, Subgraphs, Edge, or Datasets — those have their own skills."
---

# Goldsky Compose

Goldsky Compose is the offchain-to-onchain framework for high-stakes systems. Write TypeScript **tasks** that run in verifiable sandboxes — triggered by cron, HTTP, or onchain events — with smart wallets, gas sponsorship, and durable collections. Typical use cases: custom price oracles, keepers, circuit breakers, prediction-market resolvers, cross-chain automation, identity/attestation flows, and notifications.

## Step 0 — Load the reference first

**Before anything else — before you write any `compose.yaml` or task file, quote a field / flag / API shape, or scaffold or deploy an app — load `Skill(compose-reference)`.** It's the full manifest / CLI / `TaskContext` / wallet / gas-sponsorship reference. This skill gives the rules and the shape of a build; `compose-reference` gives the exact fields and signatures — and per the Golden rules below, the manifest / CLI / API must never be synthesized from memory. Do not emit a manifest or task without it loaded.

## Skill family — load `compose` first

`compose` is the entry point for anything Goldsky Compose: **load it first, then pull in the others as needed.**

- **General build rules and concepts** — this skill. It governs every Compose conversation, in-app or local.
- **A specific example** (bitcoin oracle, VRF, dividend distribution, compliance-gated payments) — also load the matching template (`/compose-bitcoin-oracle`, `/compose-vrf`, `/compose-dividend-distribution`, `/compose-compliance-oracle`). Each carries that app's source and specifics and relies on the rules here; it does not repeat them.
- **Any field, flag, manifest shape, or API signature** — load `/compose-reference`. It's the full reference docs. Consult it before writing any `compose.yaml` or task file.
- **A broken app** — `/compose-doctor`.

## Template catalog

The worked-example templates are starting points for whole classes of app, not just their literal use case. Match a new app against this catalog by **scope and pattern**, not by name:

| Template | Scope / pattern | Start here when the app is… |
| --- | --- | --- |
| `/compose-bitcoin-oracle` | cron → fetch offchain data → `writeContract` | a keeper or oracle that periodically pushes a value onchain |
| `/compose-vrf` | `onchain_event` → fetch → write back with proof | event-driven request/response, verifiable callbacks |
| `/compose-dividend-distribution` | CLI-driven; spawns a Turbo pipeline; gas-sponsored pro-rata payouts | batch payouts, snapshot-then-distribute, cap-table style |
| `/compose-compliance-oracle` | `onchain_event` → screen via external API → `writeContract` approve/reject callback | a payment or action held in escrow that an offchain check (AML/KYC, risk, allowlist) must approve or reject before it settles |

The survey against this catalog is a required build step — see **Step 3** below.

## Golden rules (all modes, including the in-app deploy card)

- **Never assume anything about the app on the user's behalf.** Derive what you can from what the user actually said; for anything material to how the app is built or behaves that you cannot derive — contract address, chain, ABI, trigger cadence, wallet choice, secret values — **ask the user**. Do not invent it, guess it, or carry a value over from an example.
- **Never synthesize the manifest, CLI, or API shape from memory.** Load `/compose-reference` and follow it before emitting `compose.yaml` or a task file. This applies equally to the in-app `deployComposeApp` flow.
- **When unsure about anything that affects how the app works, ask rather than proceed.**

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

> **Import rule (or the deploy fails to bundle / crashes at runtime):** never `import` the Compose capabilities or an EVM SDK for them — `evm`, `fetch`, `collection`, etc. come from the `context` argument (there is no `@goldsky/compose-evm` package). Beyond that it depends on the app: a **Deno-style app (no `package.json`)** may import only `compose` + sibling files; an **esbuild app (has a `package.json`)** may import the npm deps it declares for pure/local use (e.g. `viem`/`@ethersproject/wallet` for signing), but must route all network I/O through `context.fetch` — packages that do their own HTTP (`axios`, `node-fetch`) fail. **Before generating `compose.yaml` and task files to deploy (especially an in-app `deployComposeApp` deploy), load `/compose-reference`** and follow its manifest schema + sandbox import rule — don't synthesize the manifest shape or imports from memory.

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

### Step 3 — Match against the worked examples, then scaffold

**If a template skill is already loaded** (the user asked for that specific example), skip the survey and build from it.

**Otherwise the survey is required before scaffolding.** Compare the derived trigger + behavior against the Template catalog above:

- **A template matches in scope** → load it (`/compose-<name>`) and start from its source instead of a blank init.
- **None match** → say so in one line, then `goldsky compose init <name>` and inspect the scaffold for the canonical file layout.

Never build a custom app without doing this comparison first.

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
