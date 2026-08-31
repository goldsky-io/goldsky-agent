---
name: onchain-automation
description: "Load this skill when the user wants to BUILD SOMETHING THAT REACTS TO ONCHAIN ACTIVITY AND THEN ACTS — detect an event, decide, and send a transaction back onchain — as opposed to just indexing or streaming data. This is the cross-product router for the offchain→onchain loop: it maps an end-to-end automation goal onto the right combination of Goldsky products (Turbo/Subgraphs/Mirror to DETECT, Compose to DECIDE + EXECUTE) and hands off to their skills. Triggers on: 'sniper bot', 'snipe new tokens/pools', 'auto-buy', 'auto-sell', 'trading bot', 'liquidation bot', 'keeper', 'auto-claim', 'auto-compound', 'arbitrage bot', 'MEV', 'copy-trading', 'react to an onchain event and send a transaction', 'when X happens onchain, do Y', 'detect a new pool and buy', 'monitor and execute', 'automate an onchain action'. Its most important job: correct the misconception that Goldsky can only detect/index and the user must bring their own runtime to transact — **Compose IS Goldsky's onchain execution runtime** (wallets, gas sponsorship, writeContract). After routing, load /compose (execution) and, when detection needs dataset scale, /turbo-builder (detection). Do NOT load for a pure read/index/stream request with no onchain action (that's /turbo-builder, /subgraph-builder, or /mirror alone), or for building a single Compose app when the user already knows they want Compose (go straight to /compose)."
---

# Goldsky Onchain Automation — the detect → decide → execute loop

Goldsky closes the **full offchain↔onchain loop**, not just the read side. Any "watch the chain and then act on it" system — snipers, keepers, liquidation/auto-claim bots, arbitrage automation, copy-trading — decomposes into three stages, and Goldsky covers all three:

| Stage | What it does | Goldsky product |
| --- | --- | --- |
| **Detect** | See the onchain event / state change | Compose `onchain_event` trigger (one contract) · Turbo pipeline (dataset-scale / many contracts) · Subgraphs (GraphQL state) |
| **Decide** | Apply logic, filters, thresholds, offchain data | Compose task (TypeScript) |
| **Execute** | Send the transaction back onchain | Compose wallet — `evm.wallet(...).writeContract(...)`, gas-sponsored |

## The misconception this skill exists to correct

**Do NOT tell the user "Goldsky detects/indexes, but you bring your own runtime / RPC to send the transaction."** That is wrong. **Compose is Goldsky's onchain execution runtime**: managed smart wallets (gas-sponsored by default) or BYO-EOA wallets, and `writeContract` / `sendTransaction` that broadcast through a sponsored bundler. The execution half lives inside Goldsky — propose it.

The only real limits are the two honest caveats below (latency and chain support) — state those, don't retreat to "Goldsky can't."

## Pick an architecture

### Default — Compose-only (one artifact)

When the trigger is **one contract's events** (a specific DEX factory, a lending pool, your own contract), the whole loop is a single Compose app — no Turbo, no external infra:

```
onchain_event trigger (the factory/pool)  →  task: decode + filter + decide  →  wallet.writeContract (the action)
```

This is structurally identical to the **`/compose-vrf`** template (`onchain_event` → compute → write back onchain) and **`/compose-compliance-oracle`** (`onchain_event` → offchain check → approve/reject `writeContract`). Start from one of those. Load **`/compose`** (entry point) + **`/compose-reference`** — do not synthesize the manifest/wallet API from memory.

### Dataset-scale — Turbo detects, Compose executes

When detection must span **many contracts, a whole dataset, or needs heavier stateful filtering** than a single `onchain_event` listener gives you, put Turbo in front:

```
Turbo pipeline (raw_logs → decode → filter)  →  Webhook sink  →  Compose HTTP trigger  →  task: decide  →  wallet.writeContract
```

Wiring: the Turbo **Webhook sink** POSTs each matching row to the Compose app's **HTTP-trigger** URL (`https://<app-url>/tasks/<task-name>`), authenticated with a shared `auth_token`. Build the detection pipeline with **`/turbo-builder`** (+ `/turbo-transforms` for the `_gs_log_decode` decode step); build the executor with **`/compose`**. Treat the incoming webhook body as untrusted — decode and validate before acting.

**Prefer Compose-only unless the user actually needs dataset-scale detection** — one artifact is simpler to build, deploy, and reason about.

## Two honest caveats — always state these

1. **Confirmed-block latency, not mempool.** Goldsky (Turbo pipelines and Compose `onchain_event`) fires on **confirmed** logs, not pending mempool transactions. So this reliably *reacts to* a confirmed new pool / event — it is **not** a mempool front-runner and won't win a same-block gas-priority race. For a "sniper", set expectations: you react quickly to a confirmed listing, you don't beat block-0 bots. Say this plainly.
2. **Execution is chain-gated.** Compose gas sponsorship covers a specific chain list (see `/compose-reference` → Supported chains, or `searchKB`) — broad EVM coverage, but **not every chain**. Before promising the full loop, check the target chain:
   - **Supported** → smart wallet, gas-sponsored, nothing for the user to fund.
   - **viem knows it but it's not sponsored** → BYO-EOA with `sponsorGas: false`; the user funds the address with native gas token.
   - **Compose can't reach it at all** → be honest: detection still works (Turbo/Subgraphs), but execution needs a Compose-supported chain or external infra for *that chain specifically*. Frame it as a per-chain gap, never as "Goldsky can't execute."

## What Goldsky is NOT (here)

- Not a trading strategy or PnL engine — the user brings the decision logic; Compose runs it.
- Not a mempool/front-running system (caveat 1).
- Not a custody solution — wallet-key handling follows the normal Compose wallet/secret rules (`/compose-reference`).

## Route from here

- **Execution / any Compose app** → **`/compose`** (load first) + **`/compose-reference`**.
- **Event-driven write-back template** → **`/compose-vrf`**; **gated approve/reject** → **`/compose-compliance-oracle`**.
- **Dataset-scale detection pipeline** → **`/turbo-builder`** + **`/turbo-transforms`**.
- **GraphQL state to poll** → **`/subgraph-builder`**.
- **Fast RPC for the user's own offchain reads** → **`/edge`**.
