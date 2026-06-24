---
name: compose-dividend-distribution
description: "Build and deploy the Goldsky Compose dividend-distribution (corporate-actions) example under the user's own account — given a cap table of share-token holders and a per-distribution amount, it pays every holder pro-rata in one HTTP request: snapshots holders at an operator-supplied record block via an on-demand job-mode Turbo pipeline, pays each holder with gas-sponsored writes, and leaves a tamper-evident on-chain audit trail. Idempotent and crash-safe (re-POST the same campaignId to resume; the on-chain AlreadyPaid guard makes double-pay impossible). Triggers on: 'build a dividend distribution', 'pay dividends to shareholders', 'corporate actions payout', 'distribute to a cap table', 'pro-rata token distribution onchain', 'coupon/rebate/airdrop distributor', 'set up / deploy the corporate-actions example'. Recommends shared fully-unpermissioned contracts on Base Sepolia so there's nothing to deploy. Scaffolds from goldsky-io/documentation-examples, walks CLI install, contract choice, the project key + auto Neon DB, building a cap table, and a smoke test. For a custom/novel Compose app, use /compose. For debugging, use /compose-doctor. For manifest/CLI/API field lookups, use /compose-reference."
---

# Build: Compose dividend-distribution

Stand up the corporate-actions distributor under the user's own Goldsky account. One HTTP request (`declare_campaign`) drives the whole lifecycle: validate the record block → approve USDC and `declare()` the campaign (pulls escrow atomically) → spawn a one-shot **job-mode Turbo pipeline** that snapshots share-token `Transfer` rows up to the record block into an auto-provisioned Neon DB → aggregate balances → fire up to 25 concurrent gas-sponsored `pay()` calls → confirm `escrowRemaining == 0` → delete the pipeline. The interesting bit: **Compose orchestrates Turbo as an ephemeral, on-demand subroutine** — no always-on indexing.

This skill is the single source of truth for the procedure. It merges the runnable example in `goldsky-io/documentation-examples` (`compose/corporate-actions`) with the in-app seed-prompt flow. The recommended path uses **shared, fully-unpermissioned contracts on Base Sepolia**, so the user deploys nothing and the Compose smart wallet is auto-created and gas-sponsored. Assume the user has never used Goldsky Compose before. Do not skip preflight.

## Mode Detection

Check whether the `Bash` tool is available before running anything:

- **Bash available (CLI / local-agent mode):** execute the steps below directly, parse output, and substitute captured values into later commands.
- **Bash NOT available (webapp chatbot / reference mode):** you cannot scaffold or deploy from a shell. First reply with a plain 2-3 sentence explanation, then ask the user to confirm. Generate the files inline, wire the shared contract addresses, and present the deploy card / one command at a time. Point them at `npx skills add goldsky-io/goldsky-agent` to run this with Bash locally.

## Non-negotiables

- **The shared contracts on Base Sepolia are fully unpermissioned and for getting-started/demos only — never production. Say this in prose.** MockUSDC (6-decimal, open `mint`) at `0x8ec24F07F08745fc3D979336AA81d4Dc73f3D9DE`; OpenShareToken (symbol `OSHARE`, open `mint(address,uint256)`) at `0xCAA2c65b1A1526bdBA28cF7b32b0E0a59A88102a`; DistributionCampaign (permissionless — each caller runs their own campaigns) at `0xA8e58573B1e10908b63d12B603aCF9C784BF904E`. They exist only on Base Sepolia.
- **Never run `forge create` / `./scripts/deploy.sh`, `goldsky compose deploy`, `goldsky secret create`, `git push`, or `gh repo create` without showing the exact command first and getting explicit confirmation.**
- **`recordBlock` must be `<= chain head`.** The snapshot is backward-looking. Future-dated record blocks are not supported in this demo. Recommend a block past finality (e.g. `head - 32`).
- **`campaignId` is a 0x-prefixed 32-byte hex string, unique per operator.** Re-POSTing the same id resumes the existing campaign; it does not re-declare. The contract's `AlreadyPaid` guard + on-chain `isPaid()` read make double-pay structurally impossible, so resumes are always safe.
- **`GOLDSKY_PROJECT_KEY` is a project API key the running app uses to spawn/poll/delete Turbo pipelines.** Set it as a project secret before deploy.

## Variable handling for agents

When this skill says `$FOO`, capture the literal value from the prior command's output and substitute it directly into the next command. Do not rely on shell variables persisting between separate Bash tool invocations — each invocation gets a fresh shell with no env carryover from earlier commands.

## Step 0 — Scaffold the example

Pull just the corporate-actions example into a fresh directory (no git history):

```bash
npx degit goldsky-io/documentation-examples/compose/corporate-actions corporate-actions
cd corporate-actions
```

If `npx degit` is unavailable, fall back to a sparse clone:

```bash
git clone --depth 1 --filter=blob:none --sparse https://github.com/goldsky-io/documentation-examples.git
cd documentation-examples && git sparse-checkout set compose/corporate-actions && cd compose/corporate-actions
```

If the user already cloned the example, skip this step and `cd` into it.

## Preflight

1. **`goldsky` CLI** — `goldsky --version`. Install per https://docs.goldsky.com/reference/cli.
2. **`goldsky` authenticated** — `goldsky project list`. If it errors, stop and tell the user: "Please run `goldsky login` in your terminal — browser flow. Tell me to continue when you see the success message." Do not spawn `goldsky login` from Bash.
3. **`node` + `npm`** — `npm --version`. Run `npm install` (the example uses `viem`).
4. **`foundry`** — `cast --version` / `forge --version`. Needed to build the cap table (mint OpenShareToken) and on the deploy-your-own path.

## Step 1 — Configuration interview

Ask about contracts only; for everything else use the example's defaults without asking. One question at a time, recommended option tagged, addresses in prose (never in option labels):

1. **"Payout token (the ERC-20 dividends are paid in)?"** — **Use the shared open-mint MockUSDC on Base Sepolia (recommended)** at `0x8ec24F07F08745fc3D979336AA81d4Dc73f3D9DE` (open mint, so you can fund yourself test tokens), or **paste my own ERC-20**.
2. **"Share token (its holder balances at the record block define the cap table)?"** — **Use the shared open-mint OpenShareToken (OSHARE) on Base Sepolia (recommended)** at `0xCAA2c65b1A1526bdBA28cF7b32b0E0a59A88102a` (anyone can `mint(address,uint256)` to build a cap table), or **paste my own ERC-20**.
3. **"DistributionCampaign contract?"** — **Reuse the shared campaign on Base Sepolia (recommended)** at `0xA8e58573B1e10908b63d12B603aCF9C784BF904E` (permissionless), or **deploy my own** (Step 2, deploy-your-own).

Do NOT ask about the cap-table source, the trigger, or batching — the example fixes those: cap table from an on-chain `Transfer` snapshot via a one-shot job-mode Turbo pipeline at the record block; payouts bundled as concurrent gas-sponsored `pay()` calls signed by the auto-provisioned Compose smart wallet (do not tell the user to create or fund a wallet).

## Step 2 — Wire the contract addresses

- **Shared path (recommended):** edit `src/lib/constants.ts` (use grep anchors) so `CONFIG` points at the three shared Base Sepolia addresses above, the chain is `baseSepolia`, and `shareTokenDeployBlock` is the block OpenShareToken was deployed at (already set in the repo for the shared contracts; if absent, read it from `https://sepolia.basescan.org/address/0xCAA2c65b1A1526bdBA28cF7b32b0E0a59A88102a`). The snapshot pipeline filters `block_number BETWEEN <shareTokenDeployBlock> AND <recordBlock>`, so this lower bound matters.
- **Deploy-your-own path:** the example deploys MockUSDC + ShareToken + DistributionCampaign via Foundry. Show, then (on confirmation) run:
  ```bash
  PRIVATE_KEY=0x<deployer with a little ETH> ./scripts/deploy.sh
  ```
  It prints the three addresses and the ShareToken deploy block. Copy them into `src/lib/constants.ts` (`shareToken` + `shareTokenDeployBlock` + the others).

## Step 3 — Set the project key secret

The running app spawns/polls/deletes Turbo pipelines with this key:

```bash
goldsky secret create GOLDSKY_PROJECT_KEY <your project API key>
```

Declared in `compose.yaml`'s `secrets:` block. On deploy, compose-cloud also auto-provisions a hosted Neon DB and a `CORPORATE_ACTIONS` project secret pointing at it — the job-mode pipelines write snapshots there. No glue code needed.

## Step 4 — Deploy to Goldsky

```bash
goldsky compose deploy
```

The operator wallet address (the auto-provisioned, gas-sponsored Compose smart wallet) is printed in the app logs on first request.

## Step 5 — Build a cap table (shared OpenShareToken)

Mint OSHARE to a few holder addresses so there's a cap table to snapshot. OpenShareToken's `mint` is open:

```bash
cast send 0xCAA2c65b1A1526bdBA28cF7b32b0E0a59A88102a "mint(address,uint256)" <HOLDER_ADDR> <AMOUNT> \
  --rpc-url https://sepolia.base.org --private-key $PRIVATE_KEY
```

Repeat for each holder with uneven amounts. (Deploy-your-own ShareToken pre-mints to the 25 demo holders in `scripts/seed-holders.json` instead.) Then fund the operator wallet with MockUSDC so it has escrow to distribute — MockUSDC's mint is open too:

```bash
cast send 0x8ec24F07F08745fc3D979336AA81d4Dc73f3D9DE "mint(address,uint256)" <OPERATOR_WALLET> 1000000000000 \
  --rpc-url https://sepolia.base.org --private-key $PRIVATE_KEY
# 1000000000000 = 1,000,000 mUSDC (6 decimals)
```

## Step 6 — Smoke test: declare a distribution

`declare_campaign` is HTTP-triggered with `authentication: "auth_token"`. POST `campaignId` (0x 32-byte hex), `recordBlock` (≤ chain head, ideally past finality), and `totalAmount` (6-decimal mUSDC). Use a Compose API token from the dashboard:

```bash
curl -X POST -H "Authorization: Bearer $COMPOSE_TOKEN" -H "Content-Type: application/json" \
  "https://api.goldsky.com/api/admin/compose/v1/<app name>/tasks/declare_campaign" \
  -d '{"campaignId":"0x0000000000000000000000000000000000000000000000000000000000000001","recordBlock":<RECENT_BLOCK_MINUS_32>,"totalAmount":"10000000000"}'
# totalAmount 10000000000 = 10,000 mUSDC
```

The single request runs declare → spawn snapshot pipeline → poll `/state` every 2s → pay holders → confirm `escrowRemaining == 0` → delete the pipeline. Tail `goldsky compose logs` to watch the phases. Verify on-chain: `HolderPaid` events on the DistributionCampaign at `https://sepolia.basescan.org/address/<campaign>#events`, one per holder. Re-POST the same `campaignId` to confirm idempotency (a completed campaign returns without re-paying).

## Troubleshooting

- **Edits don't take effect after redeploy.** Stale `.compose/` bundle cache. `rm -rf .compose/` and redeploy.
- **Snapshot never completes / `state=unknown` with no rows.** The Turbo job's `block_number` window is wrong — check `shareTokenDeployBlock` in `constants.ts` and that `recordBlock` is after it and ≤ chain head.
- **`recordBlock` rejected.** It must be `<= chain head`; future-dated blocks aren't supported here.
- **Pipeline spawn fails / 401 from the pipelines API.** `GOLDSKY_PROJECT_KEY` is missing or wrong. Re-create it (Step 3).
- **No holders paid / total is 0.** The cap table is empty — mint OSHARE to some addresses (Step 5) at or before the record block.
- **`pay()` reverts with insufficient escrow.** The operator wallet didn't approve/escrow enough MockUSDC; mint more mUSDC to the operator wallet and re-POST the campaign.

## What you should NOT do

- Do not use the shared Base Sepolia contracts in production — they're open to anyone.
- Do not make the snapshot window unbounded (drop the `shareTokenDeployBlock` lower bound). The planner prunes outside the window; an unbounded backfill is slow and unnecessary.
- Do not try to make compose track "did this holder get paid?" in its own state — the contract is the source of truth (`isPaid()` + `AlreadyPaid`). Re-POST resumes safely off-chain state notwithstanding.
- Do not change the per-campaign sink table naming (`share_balances_<id>`) — per-campaign tables prevent cross-campaign aggregate contamination.

## Related

- **`/compose`** — Build a new/custom Compose app from scratch, or explain what Compose is.
- **`/compose-reference`** — Manifest, CLI, TaskContext API, wallets, gas sponsorship, codegen.
- **`/compose-doctor`** — Diagnose and fix a broken Compose app.
- **`/turbo-pipelines`** — Turbo job-mode pipelines (the snapshot subroutine this example spawns).
