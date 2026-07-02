---
name: compose-bitcoin-oracle
description: "Build and deploy the Goldsky Compose bitcoin-oracle example under the user's own account — a cron task that fetches BTC/USD from CoinGecko and writes `(timestamp, price)` as `bytes32` values to an on-chain `PriceOracle` contract via a Compose-managed wallet, appending each price to a durable collection. Triggers on: 'build a bitcoin price oracle', 'BTC/USD oracle onchain', 'push a price feed onchain', 'cron price oracle', 'set up / deploy the bitcoin-oracle example', 'compose price oracle'. Recommends the shared fully-unpermissioned oracle on Base Sepolia so there's nothing to deploy. Scaffolds the example from goldsky-io/documentation-examples, walks CLI install, contract choice (reuse shared / deploy own), wiring, optional GitHub publish, and a log-tailing smoke test. For a custom/novel Compose app that isn't this oracle, use /compose. For debugging an already-deployed app, use /compose-doctor. For manifest/CLI/API field lookups, use /compose-reference."
---

# Build: Compose bitcoin-oracle

Stand up the bitcoin-oracle example under the user's own Goldsky account. A cron task fetches BTC/USD from CoinGecko and writes `(timestamp, price * 100)` as two `bytes32` values to a `PriceOracle` contract via a Compose-managed wallet. It also appends the price to a Compose `collection` for historical queries.

This template supplies only what's specific to the bitcoin-oracle app — how it works and its source. The recommended path uses a **shared, fully-unpermissioned `PriceOracle` on Base Sepolia**, so the user deploys nothing and the Compose smart wallet is auto-created and gas-sponsored.

## Step 0 — Load the base skills first

**Before anything else — before you answer, ask a question, scaffold a file, or call `deployComposeApp` — load the two base skills this template depends on:**

1. **`Skill(compose)`** — the always-on Compose guide: the golden rules (never assume anything about the app on the user's behalf; ask when unsure) and general build guidance.
2. **`Skill(compose-reference)`** — the manifest / field / API reference; consult before writing any `compose.yaml` or task file.

This template deliberately omits those rules and that reference — they are **required** to build correctly and are not repeated here. Do not proceed until both are loaded.

## Mode Detection

Pick the mode from the tools available to you:

- **A `deployComposeApp` tool is available (Goldsky webapp chatbot) — this is the preferred in-app flow.** Do NOT emit `goldsky` terminal commands or `cliCommand` cards, and do NOT use Step 0 / `degit` / `forge` / `goldsky compose deploy`. **Do NOT ask the user what to name the app** — name it `bitcoin-oracle` automatically; they can rename it after deploy. Give a 2-3 sentence plain explanation, then ask with `askUser` (tag the recommended option with `recommendedIndex`):
  1. **Contract** — ask this explicitly, do not assume: *"Do you have your own `PriceOracle` contract, or should we use a shared demo oracle on Base Sepolia to get running quickly?"* Options: **"Use the shared demo oracle on Base Sepolia (recommended — nothing to deploy)"** and **"I'll use my own contract."** On the shared path, `ORACLE_CONTRACT` is the **HARDCODED** address `0x53deB3fF6E6e82A3b5E96f14E185e3Fe66BF5113` on `baseSepolia` — copy it character-for-character; mention in prose it's demos-only, not production. On the own path, ask the user to paste their contract address and chain and use exactly what they paste (their `PriceOracle` must let the Compose wallet write).
  2. **Update frequency** (recommend every minute, `* * * * *`).

  The Compose smart wallet is auto-created at runtime and gas-sponsored — never tell the user to create or fund a wallet. After the questions, scaffold the files in-memory (do NOT degit): `compose.yaml` (a single cron task on the chosen schedule), `src/contracts/PriceOracle.json` (the verbatim ABI in Step 3), and `src/tasks/bitcoin-oracle.ts` (fetch BTC/USD from CoinGecko, then `evm.contracts.PriceOracle.write(toBytes32(timestamp), toBytes32(Math.round(price*100)))` via the gas-sponsored smart wallet, appending each price to a `bitcoin_prices` collection). `ORACLE_CONTRACT` is a **hardcoded `const` at the top of the task file, not an env var** — do not put it under the manifest `env:` key. Follow `/compose-reference` for the manifest shape and the sandbox import rule before emitting the files (per the golden rules in `/compose` — don't synthesize the manifest from memory). Then **call `deployComposeApp` in the SAME turn**; don't ask the user to confirm first or emit any `goldsky` command. **In this mode, ignore Steps 0–8 below** — they are the CLI/local procedure.
- **`Bash` is available (local CLI / coding agent):** execute the steps below directly, parsing output into later commands.
- **Neither (pure reference Q&A):** explain what the app does; for step-by-step help point them at `npx skills add goldsky-io/goldsky-agent` to run it locally with Bash.

## Non-negotiables

- **The shared oracle at `0x53deB3fF6E6e82A3b5E96f14E185e3Fe66BF5113` on Base Sepolia is fully unpermissioned — anyone can write to it.** It exists for getting started and demos only. Tell the user, in prose, that it must NOT be used in production. It only exists on Base Sepolia.
- **Never run `forge create`, `goldsky compose deploy`, `git push`, or `gh repo create` without showing the exact command first and getting explicit confirmation.**
- **Deploy-your-own path only:** the contract's authorized writer must be the Compose wallet, or every `write()` reverts. On the shared-oracle path there is no writer restriction, so this does not apply.
- **The example ships only `src/contracts/PriceOracle.json` (the ABI), not Solidity source.** If deploying fresh, use the reference contract in this skill. Write the ABI verbatim — see Step 3.
- **Do not touch `src/lib/utils.ts`.** `toBytes32` is coupled to how the contract stores the value.

> **Steps 0–8 below are the Bash / local-CLI procedure. If a `deployComposeApp` tool is available (webapp chatbot), do NOT follow them — use the deploy-tool flow in Mode Detection above.**

## Step 0 — Scaffold the example

Pull just the bitcoin-oracle example into a fresh directory (no git history):

```bash
npx degit goldsky-io/documentation-examples/compose/bitcoin-oracle bitcoin-oracle
cd bitcoin-oracle
```

If `npx degit` is unavailable, fall back to a sparse clone:

```bash
git clone --depth 1 --filter=blob:none --sparse https://github.com/goldsky-io/documentation-examples.git
cd documentation-examples && git sparse-checkout set compose/bitcoin-oracle && cd compose/bitcoin-oracle
```

If the user already cloned the example, skip this step and `cd` into it.

## Preflight

The `goldsky` CLI, auth, and `deno` checks are the standard Compose preflight — see `/compose` and `/auth-setup`. Bitcoin-oracle-specific: **`foundry`** (`forge --version`) is needed only on the deploy-your-own path (Step 3, Branch B).

## Step 1 — Configuration

Name the app `bitcoin-oracle` (don't ask). Then, per the golden rules in `/compose`, ask only what you can't derive:

1. **"Which chain?"** — **Base Sepolia (recommended)** because it has the ready, fully-unpermissioned shared oracle (nothing to deploy). Other options (Base, Arbitrum, Polygon Amoy, etc.) require deploying your own oracle. Use the camelCase form in TS (`baseSepolia`).
2. **"PriceOracle contract?"** (ask immediately after the chain) — two options:
   - **Reuse the shared oracle on Base Sepolia (recommended)** — nothing to deploy. Wire `0x53deB3fF6E6e82A3b5E96f14E185e3Fe66BF5113` (mention the address in prose, not in any option label). Demos/getting-started only, not production.
   - **Deploy my own** — see Step 3, Branch B. (Required on any chain other than Base Sepolia.)
3. **"How often should the cron run?"** — Every minute (recommended, `* * * * *`), every 5 minutes (`*/5 * * * *`), or every hour. Set the `expression:` under the `cron` trigger in `compose.yaml`.

## Step 2 — Wallet

- **Shared-oracle path (recommended):** nothing to do. The Compose smart wallet is auto-created at runtime and fully gas-sponsored on Base Sepolia. Do NOT tell the user to create or fund a wallet.
- **Deploy-your-own path:** you need the wallet address *before* deploying the contract so you can set it as the authorized writer. Provision the named wallet (matches `evm.wallet({ name: "bitcoin-oracle-wallet" })` in `src/tasks/bitcoin-oracle.ts`) and capture its address as `$COMPOSE_WALLET`:
  ```bash
  goldsky compose wallet create bitcoin-oracle-wallet
  ```

## Step 3 — Contract

**Branch A — Reuse shared oracle (recommended).** `$CONTRACT_ADDRESS = 0x53deB3fF6E6e82A3b5E96f14E185e3Fe66BF5113` on Base Sepolia. No deploy, no writer authorization. Skip to Step 4.

**Branch B — Deploy your own.** First confirm `src/contracts/PriceOracle.json` contains exactly this ABI (write it verbatim if scaffolding inline; never invent ABI):

```json
[{"inputs":[{"internalType":"bytes32","name":"timestamp","type":"bytes32"},{"internalType":"bytes32","name":"price","type":"bytes32"}],"name":"write","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[],"name":"latestTimestamp","outputs":[{"internalType":"bytes32","name":"","type":"bytes32"}],"stateMutability":"view","type":"function"},{"inputs":[],"name":"latestPrice","outputs":[{"internalType":"bytes32","name":"","type":"bytes32"}],"stateMutability":"view","type":"function"},{"anonymous":false,"inputs":[{"indexed":true,"internalType":"bytes32","name":"timestamp","type":"bytes32"},{"indexed":false,"internalType":"bytes32","name":"price","type":"bytes32"}],"name":"PriceUpdated","type":"event"}]
```

Run `mkdir -p contracts`, write this reference Solidity to `contracts/PriceOracle.sol`:

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract PriceOracle {
    address public writer;
    bytes32 public latestTimestamp;
    bytes32 public latestPrice;

    event PriceUpdated(bytes32 indexed timestamp, bytes32 price);

    error OnlyWriter();

    constructor(address _writer) { writer = _writer; }

    function setWriter(address newWriter) external {
        if (msg.sender != writer) revert OnlyWriter();
        writer = newWriter;
    }

    function write(bytes32 timestamp, bytes32 price) external {
        if (msg.sender != writer) revert OnlyWriter();
        latestTimestamp = timestamp;
        latestPrice = price;
        emit PriceUpdated(timestamp, price);
    }
}
```

Then output this for the user to run with their own funded EOA (constructor arg authorizes the Compose wallet from Step 2):

```bash
forge create contracts/PriceOracle.sol:PriceOracle \
  --rpc-url <RPC_URL_FOR_CHOSEN_CHAIN> \
  --private-key $PRIVATE_KEY \
  --broadcast \
  --constructor-args $COMPOSE_WALLET
```

RPC URLs: `baseSepolia` → `https://sepolia.base.org`, `base` → `https://mainnet.base.org`, `polygonAmoy` → `https://rpc-amoy.polygon.technology`, `polygon` → `https://polygon-rpc.com`, `arbitrum` → `https://arb1.arbitrum.io/rpc`, `optimism` → `https://mainnet.optimism.io`. Capture `Deployed to: 0x...` as `$CONTRACT_ADDRESS`. (Already have a `PriceOracle`-shaped contract? Grant the Compose wallet write permission via `setWriter($COMPOSE_WALLET)` from the owner EOA and use its address instead.)

## Step 4 — Wire the contract address and chain into the task

Edit `src/tasks/bitcoin-oracle.ts` — use grep anchors:
- Find `const ORACLE_CONTRACT = "0x..."` near the top and replace the address with `$CONTRACT_ADDRESS`.
- Find the `evm.chains.*` reference inside the `new evm.contracts.PriceOracle(...)` call and set it to `evm.chains.<chosen chain in camelCase>` (e.g. `baseSepolia`).

If the user changed the cron cadence, edit the `expression:` under the `cron` trigger in `compose.yaml`.

## Step 5 — Gas (deploy-your-own, non-sponsored chains only)

Compose-managed wallets default to `sponsorGas: true` on sponsored chains (Base, Base Sepolia, Polygon, Polygon Amoy, and others). On those chains the wallet needs no funding — skip this step. On a non-sponsored chain, send native gas token to `$COMPOSE_WALLET` (testnet faucet, or budget for the cron cadence on mainnet: every-minute writes ≈ 1,440 tx/day).

## Step 6 — Optional: publish to a new GitHub repo

```bash
git init
git add .
git ls-files --cached | grep -iE '(keypair\.json|\.env|private[._-]?key|\.pem|id_rsa)' && \
  { echo "ABORT: secret-shaped file staged"; exit 1; }
git commit -m "Initial commit: Compose bitcoin-oracle"
gh repo create <user's repo name> --<public|private> --source=. --push
```

## Step 7 — Deploy to Goldsky

```bash
goldsky compose deploy
```

## Step 8 — Smoke test

Tail logs and wait for the next cron fire (up to 1 minute):

```bash
goldsky compose logs
```

Good output is a return payload with `success: true` and an `oracleHash` 0x-prefixed tx hash, repeating on cadence with no retries.

Verify on-chain (Base Sepolia explorer: `https://sepolia.basescan.org/address/$CONTRACT_ADDRESS#events`): you should see a `PriceUpdated` event per cron fire, and `latestPrice()` / `latestTimestamp()` should return recent `bytes32` values.

## Troubleshooting

- **Edits to `compose.yaml` or source files don't take effect after redeploy.** The local `.compose/` bundle cache is stale. Run `rm -rf .compose/` and redeploy.
- **Every cron run reverts (deploy-your-own only).** The Compose wallet isn't the authorized writer. Re-run `setWriter($COMPOSE_WALLET)` (Branch A of your own contract) or re-check the `forge create` constructor arg. (Shared oracle has no writer restriction, so this can't be the cause there.)
- **`insufficient funds for gas`.** Only possible on a non-sponsored chain with deploy-your-own. Fund `$COMPOSE_WALLET`.
- **CoinGecko 429 / rate-limited.** The default retry config (3 attempts, backoff) handles transient rate-limits. If persistent, reduce cron cadence or switch to a paid API.
- **Task runs but no events on-chain.** Confirm the `evm.chains.*` reference matches the chain where the contract lives. A wallet on the wrong chain signs a tx that never appears on the intended chain.

## What you should NOT do

- Do not change the `toBytes32` helper in `src/lib/utils.ts`. The contract reads `price` as `bytes32` and the example scales by 100 (cents); changing either side silently breaks the stored value.
- Do not use the shared Base Sepolia oracle as a production target — it's open for anyone to write.
- Do not invent the `PriceOracle` ABI. Use the verbatim ABI in Step 3.

## Related

- **`/compose`** — Build a new/custom Compose app from scratch, or explain what Compose is.
- **`/compose-reference`** — Manifest, CLI, TaskContext API, wallets, gas sponsorship, codegen.
- **`/compose-doctor`** — Diagnose and fix a broken Compose app.
- **`/auth-setup`** — `goldsky login` walkthrough.
