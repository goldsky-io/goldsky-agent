---
name: compose-dividend-distribution
description: "Build and deploy the Goldsky Compose corporate-actions / dividend-distribution example under the user's own account — a durable, idempotent distributor that pays N token holders pro-rata for a tokenized corporate action (dividend, coupon, rebate, airdrop) with an on-chain audit trail. The interesting bit: Compose orchestrates a Goldsky Turbo job-mode pipeline as an ephemeral subroutine — declaring a campaign spawns a one-shot pipeline that snapshots share-token holders at a record block, waits for it, pays each holder via a gas-sponsored wallet, then deletes the pipeline. Triggers on: 'dividend distribution', 'pay dividends onchain', 'distribute dividends to shareholders', 'corporate actions distributor', 'pro-rata payout to token holders', 'airdrop pro-rata by balance', 'cap table distribution', 'set up / deploy the dividend / corporate-actions example'. Ships pointed at shared permissionless demo contracts on Base Sepolia so there's nothing to deploy. NOTE: this example is CLI-driven — it needs a project-API-key secret and spawns Turbo pipelines at runtime, so it cannot be deployed through the in-app deployComposeApp card. For a custom/novel Compose app, use /compose. For debugging a deployed app, use /compose-doctor. For manifest/CLI/API field lookups, use /compose-reference."
---

# Build: Compose dividend distribution (corporate-actions)

Stand up the corporate-actions distributor under the user's own Goldsky account. It pays N holders pro-rata for a tokenized corporate action — dividend, coupon, rebate, airdrop — idempotently and durably, with a tamper-evident on-chain audit trail. The interesting bit: **Compose orchestrates Goldsky Turbo as an ephemeral, on-demand subroutine.** Declaring a campaign spawns a one-shot [job-mode](https://docs.goldsky.com/turbo-pipelines/job-mode) Turbo pipeline that snapshots share-token holders at the operator-supplied record block; Compose waits for it to finish, pays each holder via a gas-sponsored wallet, then deletes the pipeline. No always-on indexing.

One HTTP task (`declare_campaign`) drives the whole lifecycle: declare → escrow USDC → spawn snapshot pipeline → poll → compute pro-rata → pay up to 25 holders concurrently → verify `escrowRemaining == 0` → delete the pipeline. Re-POSTing the same `campaignId` resumes cleanly after any failure; the contract is the sole source of truth for "did this holder get paid?", so double-pays are structurally impossible.

This template supplies only what's specific to the dividend/corporate-actions app — how it works and its source. The recommended path uses **shared, permissionless demo contracts on Base Sepolia** (open `mint` on MockUSDC, open `declare()` on the campaign), so there's nothing to deploy.

## Step 0 — Load the base skills first

**Before anything else — before you answer, ask a question, scaffold a file, or run any command — load the two base skills this template depends on:**

1. **`Skill(compose)`** — the always-on Compose guide: the golden rules (never assume anything about the app on the user's behalf; ask when unsure) and general build guidance.
2. **`Skill(compose-reference)`** — the manifest / field / API reference; consult before writing any `compose.yaml` or task file.

This template deliberately omits those rules and that reference — they are **required** to build correctly and are not repeated here. Do not proceed until both are loaded.

## Mode Detection

Pick the mode from the tools available to you:

- **A `deployComposeApp` tool is available (Goldsky webapp chatbot).** This example **cannot be deployed through the in-app deploy card**, and that is expected — say so plainly. Two hard reasons: (1) it requires a project-API-key secret (`GOLDSKY_PROJECT_KEY`) that only the `goldsky` CLI / dashboard can set, and (2) at runtime it spawns, polls, and deletes **job-mode Turbo pipelines**, which the in-app single-app deploy path does not provision. So do NOT scaffold files or call `deployComposeApp`. Instead: give a 3-4 sentence explanation of what the app does and why it's CLI-driven, then walk the user through the CLI steps below (or tell them to run this skill locally with `npx skills add goldsky-io/goldsky-agent` where a `Bash` tool is available). Everything from Step 0 down is that CLI procedure.
- **`Bash` is available (local CLI / coding agent):** execute the steps below directly, parse output, and substitute captured values into later commands.
- **Neither (pure reference Q&A):** explain what the app does and the lifecycle; only if asked for step-by-step help, output one command at a time and have the user paste output back. Point them at `npx skills add goldsky-io/goldsky-agent` to run it locally with Bash.

## Non-negotiables

- **Ships pointed at shared, permissionless demo contracts on Base Sepolia — nothing to deploy.** MockUSDC has an open `mint` and DistributionCampaign has an open `declare()`, so anyone can run a campaign on them. Addresses live in `src/lib/constants.ts` (see below). Tell the user, in prose, these are demos/getting-started only, not production, and only exist on Base Sepolia.
- **This app needs a project API key in two places:** the `-t <key>` flag on `goldsky compose deploy` (to deploy), **and** a `GOLDSKY_PROJECT_KEY` secret (so the running app can spawn / poll / delete Turbo pipelines). It won't run without the secret. They can be the same key.
- **`recordBlock` must be `<= currentBlock`** and should be past finality (e.g. `currentBlock - 32`). The snapshot is backwards-looking — it's the cutoff for who gets paid. Future-dated record blocks are out of scope.
- **Never run `forge create` (deploy-your-own), `goldsky compose deploy`, `goldsky secret create`, `git push`, or `gh repo create` without showing the exact command first and getting explicit confirmation.**
- **The deployer `PRIVATE_KEY` (deploy-your-own path only) is a real EOA key.** Do not print it, commit it, or log it; pass it only as an env var to `scripts/deploy.sh`.
- **Resumable by design — never worry about double-pay.** Re-POSTing the same `campaignId` drives the existing campaign forward. A per-holder on-chain `isPaid()` check plus the contract's `require(!paid[id][holder])` guard mean Compose can crash/restart at any point with zero risk of double-paying.
- **This example does not run in a local/dev Compose cluster without Turbo pipeline infra.** It deploys against real Goldsky (app.goldsky.com), which is where a user runs it anyway.

## The manifest and demo config

The app itself is a single HTTP task plus a small TypeScript library and three Solidity contracts. It is large enough that the CLI flow **scaffolds it from `goldsky-io/documentation-examples` via `degit` (Step 0)** rather than writing every file by hand — only edit files when customizing. The two pieces worth seeing inline:

### `compose.yaml`

```yaml
name: "corporate-actions"
api_version: "stable"

# POSTGRES_CONNECTION_STRING is auto-injected at deploy time by compose-cloud.
# A Goldsky-project secret named CORPORATE_ACTIONS is created alongside it,
# referencing the same Neon DB. The job-mode Turbo pipelines that
# declare_campaign spawns (see src/lib/turbo.ts) write share-balance
# snapshots back into that DB.
secrets:
  # Project API key used to spawn / poll / delete Turbo pipelines from
  # inside declare_campaign. Set once: goldsky secret create GOLDSKY_PROJECT_KEY <key>
  - GOLDSKY_PROJECT_KEY

tasks:
  - path: "./src/tasks/declare-campaign.ts"
    name: "declare_campaign"
    triggers:
      - type: "http"
        authentication: "auth_token"
    retry_config:
      max_attempts: 1
      initial_interval_ms: 500
      backoff_factor: 1
```

### Shared demo contracts — `src/lib/constants.ts` (`CONFIG`)

The repo ships pointed at these permissionless Base Sepolia contracts. On the no-deploy path, leave them as-is:

```ts
export const CONFIG = {
  chain:      "baseSepolia" as const,   // evm.chains[chain] key (camelCase)
  turboChain: "base_sepolia",           // Turbo dataset prefix (snake_case)
  shareToken:       "0x713e0749a9Fe480322990913850e81b0F4F4dc0d", // 25 seed holders pre-minted
  payToken:         "0x8ec24F07F08745fc3D979336AA81d4Dc73f3D9DE", // MockUSDC (permissionless mint)
  campaignContract: "0xA8e58573B1e10908b63d12B603aCF9C784BF904E", // permissionless: anyone can declare()
  shareTokenDeployBlock: 42275958,      // lower bound for the snapshot pipeline's block-range filter
};
```

Deploy-your-own (Step 1, Branch B) replaces these four values with the addresses `scripts/deploy.sh` prints. The rest of the app (`src/lib/{types,normalize,math,db,turbo,driver}.ts`, `src/tasks/declare-campaign.ts`, `contracts/*.sol`) is scaffolded verbatim by `degit`; read those files in the cloned repo if the user wants to customize the payout math, the concurrency, or the pipeline shape.

## Step 0 — Scaffold the example

Pull just the corporate-actions example into a fresh directory (no git history):

```bash
npx degit goldsky-io/documentation-examples/compose/corporate-actions dividend-distribution
cd dividend-distribution
```

If `npx degit` is unavailable, fall back to a sparse clone:

```bash
git clone --depth 1 --filter=blob:none --sparse https://github.com/goldsky-io/documentation-examples.git
cd documentation-examples && git sparse-checkout set compose/corporate-actions && cd compose/corporate-actions
```

If the user already cloned the example, skip this and `cd` into it.

## Preflight

The `goldsky` CLI and auth checks are the standard Compose preflight — see `/compose` and `/auth-setup`. Dividend-specific:

1. **Project API key** — the user needs a Compose/project API key from the Goldsky dashboard (https://app.goldsky.com). It's used both as the `-t` deploy token and as the `GOLDSKY_PROJECT_KEY` secret. Ask them to have it ready; do not print it back.
2. **`node` + `npm`** — `npm --version`, then `npm install` (the app bundles `viem`).
3. **`foundry`** — `cast --version` / `forge --version`. Needed only on the deploy-your-own path (Step 1, Branch B) and for minting/verifying via `cast`.

## Step 1 — Contracts

**Branch A — Reuse the shared demo contracts (recommended).** Nothing to deploy. Leave `CONFIG` in `src/lib/constants.ts` at the shared Base Sepolia addresses shown above. Skip to Step 2.

**Branch B — Deploy your own.** Output this for the user to run with their own funded Base Sepolia EOA (~0.0005 ETH). It deploys MockUSDC + ShareToken (pre-minting to the 25 addresses in `scripts/seed-holders.json`) + DistributionCampaign:

```bash
PRIVATE_KEY=0x... ./scripts/deploy.sh
```

It prints the three addresses and the ShareToken deploy block. Copy them into `CONFIG` in `src/lib/constants.ts` (`payToken`, `shareToken`, `campaignContract`, `shareTokenDeployBlock`). To run on Base mainnet instead, see the comment in `constants.ts` and set `chain`/`turboChain` to `base`.

## Step 2 — Set the project-key secret

The running app uses this to spawn / poll / delete Turbo pipelines:

```bash
goldsky secret create GOLDSKY_PROJECT_KEY <your project API key>
```

## Step 3 — Deploy the Compose app

```bash
goldsky compose deploy -t <your project API key>
```

Compose-cloud auto-provisions a hosted Neon Postgres DB and creates a project secret named `CORPORATE_ACTIONS` pointing at it; the job-mode pipelines write snapshots into that DB. First deploy may take 1-2 minutes. Watch for `Deployed compose app: corporate-actions` and the HTTP task URL.

## Step 4 — Mint MockUSDC to the operator

The operator wallet address is printed in the app's logs on the first request (`goldsky compose logs`). On the shared demo, MockUSDC's `mint` is open, so anyone can fund it. Mint generously for many campaigns (1,000,000 mUSDC = `1000000000000`, 6 decimals):

```bash
cast send 0x8ec24F07F08745fc3D979336AA81d4Dc73f3D9DE "mint(address,uint256)" <OPERATOR> 1000000000000 \
  --rpc-url https://sepolia.base.org --private-key $PRIVATE_KEY
```

(On the deploy-your-own path, use your MockUSDC address instead.)

## Step 5 — Declare a campaign

Pick a record block past finality, then POST. `$GOLDSKY_TOKEN` is a Compose API token (bearer) for the HTTP task:

```bash
RECORD_BLOCK=$(cast block-number --rpc-url https://sepolia.base.org)
RECORD_BLOCK=$((RECORD_BLOCK - 32))

curl -sX POST "https://api.goldsky.com/api/admin/compose/v1/corporate-actions/tasks/declare_campaign" \
  -H "content-type: application/json" \
  -H "Authorization: Bearer $GOLDSKY_TOKEN" \
  -d "{
    \"campaignId\":  \"0x000000000000000000000000000000000000000000000000000000000000c0a1\",
    \"recordBlock\": $RECORD_BLOCK,
    \"totalAmount\": \"10000000000\"
  }"
```

That declares a 10,000 mUSDC distribution. The request stays open ~10-30s while Compose snapshots holders, computes pro-rata, and fires the 25 `pay()` calls in one batch. The response body includes the final campaign state (`complete` on the happy path, or `paying` if it needs another drive call — just re-POST the same `campaignId`).

## Step 6 — Verify on-chain

```bash
cast call 0xA8e58573B1e10908b63d12B603aCF9C784BF904E "getCampaign(bytes32)" <onChainId> \
  --rpc-url https://sepolia.base.org
```

`escrowRemaining` is exactly `0` once all 25 holders are paid. The full audit trail is the contract's `HolderPaid` events.

## Troubleshooting

- **Edits to `compose.yaml` or source files don't take effect after redeploy.** The local `.compose/` bundle cache is stale. Run `rm -rf .compose/` and redeploy.
- **App errors spawning the pipeline / `401` or `403` from the pipelines API.** The `GOLDSKY_PROJECT_KEY` secret is missing or wrong. Re-create it (Step 2) with a valid project API key and redeploy.
- **Snapshot never completes / campaign stuck in `snapshotting`.** Confirm `recordBlock <= currentBlock` and `>= shareTokenDeployBlock`, and that `CONFIG.shareToken` / `shareTokenDeployBlock` match the token you're distributing over. The pipeline filters `block_number BETWEEN <deployBlock> AND <recordBlock>`.
- **`declare()` reverts.** On the shared contract, ensure the operator approved and holds enough MockUSDC for `totalAmount` (mint more in Step 4). On your own contract, confirm the campaign contract points at the right pay token.
- **Campaign returns `paying` (not `complete`).** Some `pay()` calls didn't land this drive. Re-POST the same `campaignId` — already-paid holders are skipped via on-chain `isPaid()`, and the run resumes.
- **No hosted DB / snapshot rows.** Confirm the deploy created the `CORPORATE_ACTIONS` secret (compose-cloud does this automatically); if not, redeploy with `-t <key>`.

## What you should NOT do

- Do not use the shared Base Sepolia contracts as a production target — they're permissionless (anyone can mint mUSDC or declare a campaign).
- Do not deploy this to a local/dev Compose cluster that lacks Turbo pipeline infra — the snapshot step will hang. Deploy against real Goldsky.
- Do not put the `GOLDSKY_PROJECT_KEY` on a command line where it lands in shell history beyond the `secret create` call; do not commit it.
- Do not lower the `recordBlock` below `shareTokenDeployBlock`, and do not use a future block — the snapshot is backwards-looking by definition.
- Do not hand-edit the per-campaign pipeline/table names in `src/lib/constants.ts` (`pipelineName` / `aggTableName`) — they're derived from `campaignId` and must stay stable for resume to work.

## Related

- **`/compose`** — Build a new/custom Compose app from scratch, or explain what Compose is.
- **`/compose-reference`** — Manifest, CLI, TaskContext API, wallets, gas sponsorship, codegen.
- **`/compose-doctor`** — Diagnose and fix a broken Compose app.
- **`/turbo-pipelines`** / **`/turbo-operations`** — Job-mode pipeline shape and lifecycle, if customizing the snapshot.
- **`/auth-setup`** — `goldsky login` walkthrough.
