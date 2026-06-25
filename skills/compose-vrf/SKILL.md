---
name: compose-vrf
description: "Build and deploy the Goldsky Compose VRF example under the user's own account — an event-triggered task that listens for `RandomnessRequested(uint256,address)` on a consumer contract, fetches verifiable randomness from drand, and calls `fulfillRandomness` back on-chain via a Compose-managed wallet. Triggers on: 'build a VRF', 'verifiable random function onchain', 'provably fair randomness', 'onchain RNG', 'drand randomness', 'fulfill randomness request', 'set up / deploy the VRF example', 'compose randomness'. Recommends the shared fully-unpermissioned consumer on Base Sepolia so there's nothing to deploy. Scaffolds the example from goldsky-io/documentation-examples, walks CLI install, contract choice (reuse shared / deploy own), wiring the address into three files, optional GitHub publish, and an event-trigger smoke test. For a custom/novel Compose app that isn't this VRF, use /compose. For debugging an already-deployed app, use /compose-doctor. For manifest/CLI/API field lookups, use /compose-reference."
---

# Build: Compose VRF

Stand up the VRF example under the user's own Goldsky account. The app listens for a `RandomnessRequested(uint256,address)` event on an EVM contract, fetches verifiable randomness from drand, and writes it back on-chain via `fulfillRandomness(requestId, randomness, round, signature)`.

This skill is the single source of truth for the procedure. It merges the runnable example in `goldsky-io/documentation-examples` (`compose/VRF`) with the in-app seed-prompt flow. The recommended path uses a **shared, fully-unpermissioned `RandomnessConsumer` on Base Sepolia**, so the user deploys nothing and the Compose smart wallet is auto-created and gas-sponsored. Assume the user has never used Goldsky Compose before. Do not skip preflight.

## Mode Detection

Pick the mode from the tools available to you:

- **A `deployComposeApp` tool is available (Goldsky webapp chatbot) — preferred in-app flow.** Do NOT emit `goldsky` terminal commands or `cliCommand` cards, and do NOT use Step 0 / `degit` / `forge`. Give a 2-3 sentence plain explanation, then ask the config questions one at a time with `askUser` (tag the recommended option with `recommendedIndex`):
  1. **App name** (recommend `compose-vrf`).
  2. **Contract** — ask explicitly: *"Do you have your own `RandomnessConsumer`, or use a shared demo consumer on Base Sepolia to get running quickly?"* Options: **"Use the shared demo consumer on Base Sepolia (recommended — nothing to deploy)"** and **"I'll use my own contract."** On the shared path, `CONTRACT_ADDRESS` is the **HARDCODED** address `0x6273AB73C95Ba2233281F1eb8aa3b21D9352AD6d` on `baseSepolia` — copy it character-for-character, do NOT retype from memory; say in prose it's demos-only. On the own path, ask for their contract address + chain and use exactly what they paste (their contract just needs to emit `RandomnessRequested(uint256,address)` and expose `fulfillRandomness` — no fulfiller authorization needed, fulfillment is permissionless).

  The Compose smart wallet is auto-created and gas-sponsored — never tell the user to create or fund a wallet. **First load `/compose-reference`** for the manifest schema + sandbox import rule, then scaffold the files in-memory (do NOT degit): `compose.yaml` (the `onchain_event` trigger wired to the contract/chain — remember `compose.yaml` uses snake_case network names, TS uses camelCase chain ids), `src/contracts/RandomnessConsumer.json` (the verbatim ABI in Step 3), and the `fulfill-randomness` + `request-randomness` task sources following the import rule (`evm`/`fetch` from the injected `context`; only `compose` + sibling imports). Then **call `deployComposeApp` in the SAME turn** to present the in-app deploy card. After it, tell the user that, since this is event-triggered (no cron), they trigger a run by calling the `request_randomness` HTTP task or emitting `RandomnessRequested` on the contract. **Ignore Steps 0–8 below in this mode.**
- **`Bash` is available (local CLI / coding agent):** execute the steps below directly, parse output, and substitute captured values into later commands.
- **Neither (pure reference Q&A):** explain what the app does; only if asked for steps, output one command at a time. Point them at `npx skills add goldsky-io/goldsky-agent` to run it locally with Bash.

## Non-negotiables

- **The shared consumer at `0x6273AB73C95Ba2233281F1eb8aa3b21D9352AD6d` on Base Sepolia is fully unpermissioned.** It exists for getting started and demos only. Tell the user, in prose, that it must NOT be used in production. It only exists on Base Sepolia.
- **Never run `forge create`, `goldsky compose deploy`, `git push`, or `gh repo create` without showing the exact command first and getting explicit confirmation.** Output the command, wait.
- **`fulfillRandomness` is PERMISSIONLESS — any caller may fulfill.** The contract does not gate fulfillment on the caller (it only checks the request exists and isn't already fulfilled). The constructor's `_fulfiller` arg and the `OnlyFulfiller()` error are an informational deploy-time label + a guard on `setFulfiller` only — they do NOT block the Compose wallet from fulfilling. So you do NOT need to authorize the Compose wallet, and you do NOT need its address before deploying a contract. (This is why the shared consumer works for everyone.)
- **Three files share the same contract address.** If it changes, change all three.
- **`compose.yaml` uses snake_case network names (e.g. `base_sepolia`); TS code uses camelCase chain ids (e.g. `baseSepolia`).**

## Variable handling for agents

When this skill says `$FOO`, capture the literal value from the prior command's output and substitute it directly into the next command. Do not rely on shell variables persisting between separate Bash tool invocations — each invocation gets a fresh shell with no env carryover from earlier commands.

## Step 0 — Scaffold the example

Pull just the VRF example into a fresh directory (no git history):

```bash
npx degit goldsky-io/documentation-examples/compose/VRF compose-vrf
cd compose-vrf
```

If `npx degit` is unavailable, fall back to a sparse clone:

```bash
git clone --depth 1 --filter=blob:none --sparse https://github.com/goldsky-io/documentation-examples.git
cd documentation-examples && git sparse-checkout set compose/VRF && cd compose/VRF
```

If the user already cloned the example, skip this step and `cd` into it.

## Preflight

Run these checks in order. Stop and resolve each before moving on.

1. **`goldsky` CLI installed.** `goldsky --version`. If missing: `curl https://goldsky.com/install.sh | sh`, or https://docs.goldsky.com/reference/cli.
2. **`goldsky` authenticated.** `goldsky project list`. If it errors with auth, stop and tell the user: "Please run `goldsky login` in your terminal — it will open a browser. When you see the success message, tell me to continue." Do not spawn `goldsky login` from Bash. Alternatively the user can pass `--token <token>` on each command.
3. **`deno` installed.** `deno --version`. If missing: `curl -fsSL https://deno.land/install.sh | sh`.
4. **`foundry` installed** (only on the deploy-your-own path). `forge --version`. If missing: `curl -L https://foundry.paradigm.xyz | bash && foundryup`.

## Step 1 — Configuration interview

Ask one question at a time; translate readable answers to machine values yourself.

1. **"App name?"** (recommend `compose-vrf`) → `name:` at the top of `compose.yaml`.
2. **"Which chain?"** — **Base Sepolia (recommended)** because it has the ready, fully-unpermissioned shared consumer (nothing to deploy). Other options (Base, Arbitrum Sepolia, etc.) require deploying your own consumer.
3. **"RandomnessConsumer contract?"** — two options:
   - **Reuse the shared consumer on Base Sepolia (recommended)** — nothing to deploy. Wire `0x6273AB73C95Ba2233281F1eb8aa3b21D9352AD6d` (mention in prose, not in any option label). Demos/getting-started only.
   - **Deploy my own** — see Step 3, Branch B (from `contracts/RandomnessConsumer.sol`). Required on any chain other than Base Sepolia.
4. **"Publish to a new GitHub repo?"** — optional.

## Step 2 — Wallet

- **Shared-consumer path (recommended):** nothing to do. The Compose smart wallet is auto-created at runtime and fully gas-sponsored on Base Sepolia. Do NOT tell the user to create or fund a wallet.
- **Deploy-your-own path:** the smart wallet is still auto-created and gas-sponsored — and since fulfillment is permissionless you do NOT need the wallet address before deploying the contract. (The constructor's `_fulfiller` arg is just an informational label; pass any address, e.g. your own.) The example also ships a `generate_wallet` HTTP task that returns the Compose wallet address if you want it for other reasons: `goldsky compose callTask generate_wallet '{}'`. Note the example uses two wallet names — `randomness-fulfiller` (in `fulfill-randomness.ts` / `generate-wallet.ts`) and `randomness-requester` (in `request-randomness.ts`); both are auto-created/sponsored.

## Step 3 — Contract

**Branch A — Reuse shared consumer (recommended).** `$CONTRACT_ADDRESS = 0x6273AB73C95Ba2233281F1eb8aa3b21D9352AD6d` on Base Sepolia. No deploy, no fulfiller authorization. Skip to Step 4.

**Branch B — Deploy your own.** Confirm `src/contracts/RandomnessConsumer.json` contains exactly this ABI (write it verbatim if scaffolding inline; never invent ABI):

```json
[{"type":"constructor","inputs":[{"name":"_fulfiller","type":"address","internalType":"address"}],"stateMutability":"nonpayable"},{"type":"function","name":"fulfillRandomness","inputs":[{"name":"requestId","type":"uint256","internalType":"uint256"},{"name":"randomness","type":"bytes32","internalType":"bytes32"},{"name":"round","type":"uint64","internalType":"uint64"},{"name":"signature","type":"bytes","internalType":"bytes"}],"outputs":[],"stateMutability":"nonpayable"},{"type":"function","name":"fulfiller","inputs":[],"outputs":[{"name":"","type":"address","internalType":"address"}],"stateMutability":"view"},{"type":"function","name":"getRandomness","inputs":[{"name":"requestId","type":"uint256","internalType":"uint256"}],"outputs":[{"name":"randomness","type":"bytes32","internalType":"bytes32"},{"name":"round","type":"uint64","internalType":"uint64"},{"name":"signature","type":"bytes","internalType":"bytes"}],"stateMutability":"view"},{"type":"function","name":"isFulfilled","inputs":[{"name":"requestId","type":"uint256","internalType":"uint256"}],"outputs":[{"name":"","type":"bool","internalType":"bool"}],"stateMutability":"view"},{"type":"function","name":"nextRequestId","inputs":[],"outputs":[{"name":"","type":"uint256","internalType":"uint256"}],"stateMutability":"view"},{"type":"function","name":"requestRandomness","inputs":[],"outputs":[{"name":"requestId","type":"uint256","internalType":"uint256"}],"stateMutability":"nonpayable"},{"type":"function","name":"setFulfiller","inputs":[{"name":"_fulfiller","type":"address","internalType":"address"}],"outputs":[],"stateMutability":"nonpayable"},{"type":"event","name":"RandomnessRequested","inputs":[{"name":"requestId","type":"uint256","indexed":true,"internalType":"uint256"},{"name":"requester","type":"address","indexed":true,"internalType":"address"}],"anonymous":false},{"type":"error","name":"OnlyFulfiller","inputs":[]}]
```

(The full contract ABI in the example also exposes `RandomnessFulfilled`, `requests`, `AlreadyFulfilled`, and `RequestNotFound`; the subset above is what the task wires against.) Output this for the user to run with their own funded EOA (the `--constructor-args` value just sets the informational `fulfiller` label — any address works since fulfillment is permissionless; their own EOA is fine):

```bash
forge create contracts/RandomnessConsumer.sol:RandomnessConsumer \
  --rpc-url <RPC_URL_FOR_CHOSEN_CHAIN> \
  --private-key $PRIVATE_KEY \
  --constructor-args <any address — informational fulfiller label; your own EOA is fine> \
  --broadcast
```

RPC URLs: `base_sepolia` → `https://sepolia.base.org`, `base` → `https://mainnet.base.org`, `arbitrum_sepolia` → `https://sepolia-rollup.arbitrum.io/rpc`, `optimism_sepolia` → `https://sepolia.optimism.io`. Capture `Deployed to: 0x...` as `$CONTRACT_ADDRESS`. (Bringing an existing contract? Just give its address — as long as it emits `RandomnessRequested(uint256,address)` and exposes `fulfillRandomness`, no fulfiller setup is needed.)

## Step 4 — Wire the contract address and chain into code

Three files must stay in sync. Use grep/anchor strings (line numbers shift over time):

**`compose.yaml`** — top-level `name:`; inside the `onchain_event` trigger, `network:` → `<chosen chain in snake_case>` and `contract:` → `$CONTRACT_ADDRESS`.

**`src/tasks/fulfill-randomness.ts`** — `const CONTRACT_ADDRESS = "0x..."` → `$CONTRACT_ADDRESS`; the `evm.chains.<...>` reference inside `new evm.contracts.RandomnessConsumer(...)` → `evm.chains.<chosen chain in camelCase>`.

**`src/tasks/request-randomness.ts`** — same two edits as above.

Show a diff before applying, then apply with Edit.

## Step 5 — Funding (deploy-your-own, non-sponsored chains only)

On sponsored chains (including Base Sepolia) `sponsorGas: true` covers writes — skip. On a non-sponsored chain, send a little native gas token to `$COMPOSE_WALLET` (testnet faucet, e.g. https://www.alchemy.com/faucets/base-sepolia).

## Step 6 — Optional: publish to a new GitHub repo

```bash
git init
git add .
git ls-files --cached | grep -iE '(keypair\.json|\.env|private[._-]?key|\.pem|id_rsa)' && \
  { echo "ABORT: secret-shaped file staged"; exit 1; }
git commit -m "Initial commit: Compose VRF"
gh repo create <user's repo name> --<public|private> --source=. --push
```

## Step 7 — Deploy to Goldsky

```bash
goldsky compose deploy
```

Append `--token $GOLDSKY_TOKEN` if using token auth. First deploy may take 1–2 minutes; watch for `Deployed compose app: <app_name>` and the HTTP task URLs.

## Step 8 — Smoke test

Trigger a randomness request with a direct contract call (also exercises the full event-trigger path):

```bash
cast send $CONTRACT_ADDRESS "requestRandomness()" \
  --rpc-url <RPC_URL> \
  --private-key $PRIVATE_KEY
```

Wait 10–30 seconds, then tail logs:

```bash
goldsky compose logs
```

Expect `fetched drand round <N>` and `fulfilled request <requestId> in tx <hash>`. Verify on-chain:

```bash
cast call $CONTRACT_ADDRESS "isFulfilled(uint256)" <requestId> --rpc-url <RPC_URL>
# → 0x...01 (true)
```

`goldsky compose callTask` only invokes locally running tasks. For the deployed app, use the cast send above, or curl the `request_randomness` HTTP endpoint with a bearer token from the dashboard.

## Troubleshooting

- **Edits don't take effect after redeploy.** Stale `.compose/` bundle cache. `rm -rf .compose/` and redeploy.
- **Fulfillment never reverts with `OnlyFulfiller()`** — `fulfillRandomness` is permissionless. If a fulfill fails, it's `RequestNotFound` (no matching request id) or `AlreadyFulfilled` (already done), not an authorization problem. (`OnlyFulfiller()` only guards `setFulfiller`, which this flow never calls.)
- **Task doesn't fire on the event.** Check `compose.yaml` has the exact contract address and correct `network`; confirm the deploy succeeded and the trigger is active with `goldsky compose status`.
- **`insufficient funds for gas`.** Only on a non-sponsored chain with deploy-your-own. Fund `$COMPOSE_WALLET`.
- **drand fetch fails.** The default endpoint is public; the retry config handles transient failures. If persistent, check https://api.drand.sh/chains.

## What you should NOT do

- Do not modify `src/lib/drand.ts` unless explicitly swapping drand networks. The hardcoded constants are chain-specific BLS parameters — wrong values break signature verification silently.
- Do not change the event signature `RandomnessRequested(uint256,address)` in `compose.yaml` — it must match the contract.
- Do not add a `PRIVATE_KEY` secret. The Compose wallet is the signer; the user's EOA is only needed to deploy a contract on the deploy-your-own path, never at runtime.
- Do not use the shared Base Sepolia consumer as a production target.
- Do not invent the consumer ABI. Use the verbatim ABI in Step 3.

## Related

- **`/compose`** — Build a new/custom Compose app from scratch, or explain what Compose is.
- **`/compose-reference`** — Manifest, CLI, TaskContext API, wallets, gas sponsorship, codegen.
- **`/compose-doctor`** — Diagnose and fix a broken Compose app.
- **`/auth-setup`** — `goldsky login` walkthrough.
