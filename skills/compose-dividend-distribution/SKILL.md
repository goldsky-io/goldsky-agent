---
name: compose-dividend-distribution
description: "Build and deploy the Goldsky Compose corporate-actions / dividend-distribution example under the user's own account — a durable, idempotent distributor that pays N token holders pro-rata for a tokenized corporate action (dividend, coupon, rebate, airdrop) with an on-chain audit trail. The interesting bit: Compose orchestrates a Goldsky Turbo job-mode pipeline as an ephemeral subroutine — declaring a campaign spawns a one-shot pipeline that snapshots share-token holders at a record block, waits for it, pays each holder via a gas-sponsored wallet, then deletes the pipeline. Triggers on: 'dividend distribution', 'pay dividends onchain', 'distribute dividends to shareholders', 'corporate actions distributor', 'pro-rata payout to token holders', 'airdrop pro-rata by balance', 'cap table distribution', 'set up / deploy the dividend / corporate-actions example'. Ships pointed at shared permissionless demo contracts on Base Sepolia so there's nothing to deploy. Deploys fully in-app or via the CLI; the only runtime requirement is a `GOLDSKY_PROJECT_KEY` secret, set as the last step. For a custom/novel Compose app, use /compose. For debugging a deployed app, use /compose-doctor. For manifest/CLI/API field lookups, use /compose-reference."
---

# Build: Compose dividend distribution (corporate-actions)

Stand up the corporate-actions distributor under the user's own Goldsky account. It pays N holders pro-rata for a tokenized corporate action — dividend, coupon, rebate, airdrop — idempotently and durably, with a tamper-evident on-chain audit trail. The interesting bit: **Compose orchestrates Goldsky Turbo as an ephemeral, on-demand subroutine.** Declaring a campaign spawns a one-shot [job-mode](https://docs.goldsky.com/turbo-pipelines/job-mode) Turbo pipeline that snapshots share-token holders at the operator-supplied record block; Compose waits for it to finish, pays each holder via a gas-sponsored wallet, then deletes the pipeline. No always-on indexing.

One HTTP task (`declare_campaign`) drives the whole lifecycle: declare → escrow USDC → spawn snapshot pipeline → poll → compute pro-rata → pay up to 25 holders concurrently → verify `escrowRemaining == 0` → delete the pipeline. Re-POSTing the same `campaignId` resumes cleanly after any failure; the contract is the sole source of truth for "did this holder get paid?", so double-pays are structurally impossible.

This template supplies only what's specific to the dividend/corporate-actions app — how it works and its source. The recommended path uses **shared, permissionless demo contracts on Base Sepolia** (open `mint` on MockUSDC, open `declare()` on the campaign), so there's nothing to deploy.

## Step 0a — Load the base skills first

**Before anything else — before you answer, ask a question, scaffold a file, or run any command — load the two base skills this template depends on:**

1. **`Skill(compose)`** — the always-on Compose guide: the golden rules (never assume anything about the app on the user's behalf; ask when unsure) and general build guidance.
2. **`Skill(compose-reference)`** — the manifest / field / API reference; consult before writing any `compose.yaml` or task file.

This template deliberately omits those rules and that reference — they are **required** to build correctly and are not repeated here. Do not proceed until both are loaded.

## Mode Detection

Pick the mode from the tools available to you:

- **A `deployComposeApp` tool is available (Goldsky webapp chatbot).** This example deploys fully in-app. The job-mode Turbo pipeline is spawned at runtime via the Turbo API (an in-app `ctx.fetch` POST in `src/lib/turbo.ts`), not provisioned at deploy, so `deployComposeApp` deploys the app fine. In-app flow: run the Step 0b app-name interview first (the app name is the FIRST question), then scaffold these files in-memory from **The app (full source)** below and pass them to `deployComposeApp`: `compose.yaml`, `src/tasks/declare-campaign.ts`, `src/lib/constants.ts`, `src/lib/types.ts`, `src/lib/math.ts`, `src/lib/normalize.ts`, `src/lib/db.ts`, `src/lib/driver.ts`, and `src/lib/turbo.ts`. On the recommended shared-contract path there is nothing to deploy, so exclude the three `contracts/*.sol` sources (the shared path deploys nothing); on the deploy-your-own path also scaffold the `.sol` files and use `deployContract` for MockUSDC, ShareToken (passing the holder/amount arrays), and DistributionCampaign. Wire the four contract CONFIG values in `src/lib/constants.ts` (the three deployed addresses plus `shareTokenDeployBlock`), then call `deployComposeApp`. The `GOLDSKY_PROJECT_KEY` secret is the user's LAST step: the in-app deploy skips secret validation, so `deployComposeApp` succeeds without it, but the app won't run until the user adds the secret in the Compose app's dashboard **and redeploys from the dashboard** so the pod picks it up (secrets are baked into the pod at deploy, not hot-reloaded). NEVER attempt to set a secret from chat; there is no tool, by design. Note: the chatbot has no `writeContract` tool, so it cannot mint test MockUSDC to the `corp-actions-operator` wallet; before declaring a campaign the user must run the Step 4 mint via the CLI (`goldsky compose writeContract`) or the dashboard (the task does the USDC `approve` itself at declare time, but the operator wallet must hold the USDC first).
- **`Bash` is available (local CLI / coding agent):** execute the steps below directly, parse output, and substitute captured values into later commands.
- **Neither (pure reference Q&A):** explain what the app does and the lifecycle; only if asked for step-by-step help, output one command at a time and have the user paste output back. Point them at `npx skills add goldsky-io/goldsky-agent` to run it locally with Bash.

## Non-negotiables

- **Ships pointed at shared, permissionless demo contracts — nothing to deploy.** MockUSDC has an open `mint` and DistributionCampaign has an open `declare()`, so anyone can run a campaign on them. The shared demos exist on Base Sepolia by default; `src/lib/constants.ts` also lists known Base mainnet deployments you can swap to (real gas applies on mainnet). Tell the user, in prose, these are demos/getting-started only, not production.
- **One project API key does the whole job.** It's used three ways: the `-t "$GOLDSKY_PROJECT_KEY"` flag on `goldsky compose deployContract` / `deploy` / `writeContract`, the value of the `GOLDSKY_PROJECT_KEY` secret (so the running app can spawn / poll / delete Turbo pipelines), **and** as the `$GOLDSKY_TOKEN` bearer for the Step 5 HTTP task (or a separate Compose API token minted from the same project). Generate it in the Goldsky dashboard under **Settings > API Keys**. The app won't run without the secret.
- **`recordBlock` must be `<= currentBlock`** and should be past finality (e.g. `currentBlock - 32`). The snapshot is backwards-looking — it's the cutoff for who gets paid. Future-dated record blocks are out of scope.
- **Never run `goldsky compose deployContract` (deploy-your-own), `goldsky compose deploy`, `goldsky compose secret set`, `git push`, or `gh repo create` without showing the exact command first and getting explicit confirmation.**
- **Resumable by design — never worry about double-pay.** Re-POSTing the same `campaignId` drives the existing campaign forward. A per-holder on-chain `isPaid()` check plus the contract's `require(!paid[id][holder])` guard mean Compose can crash/restart at any point with zero risk of double-paying.
- **This example does not run in a local/dev Compose cluster without Turbo pipeline infra.** It deploys against real Goldsky (app.goldsky.com), which is where a user runs it anyway.

## The app (full source)

This is the complete dividend app. Scaffold these files verbatim (Step 0b writes them to disk via `degit`; the in-app flow scaffolds them in-memory from the blocks below). The shared Base Sepolia demo contracts in `src/lib/constants.ts` mean the recommended path has nothing to deploy. Only edit `src/lib/constants.ts` to wire in your own contract addresses (Step 1 Branch B) or swap to Base mainnet.

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
  # inside declare_campaign. Set once:
  #   goldsky compose secret set GOLDSKY_PROJECT_KEY --value "$GOLDSKY_PROJECT_KEY"
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

### `src/tasks/declare-campaign.ts`

```typescript
import type { TaskContext } from "compose";
import { encodePacked, keccak256 } from "viem";

import { CONFIG } from "../lib/constants";
import { driveCampaign } from "../lib/driver";
import { isHexBytes32 } from "../lib/normalize";
import { createSnapshotPipeline } from "../lib/turbo";
import type { Campaign, DeclareParams, Hex } from "../lib/types";

/**
 * HTTP trigger.
 *
 *   POST {
 *     "campaignId":  "0x<32 bytes hex>",  // operator-supplied id, unique per operator
 *     "recordBlock": 24500000,            // snapshot point; must be <= chain head
 *     "totalAmount": "10000000000"        // 10,000 mUSDC (6 decimals)
 *   }
 *
 *   1. Validate `recordBlock` is in the past (or current). Future-dated record
 *      blocks aren't supported in this demo — they're a real corp-action feature
 *      (record dates often look forward) but out of scope here.
 *   2. Approve the campaign contract for `totalAmount` of MockUSDC.
 *   3. Call `DistributionCampaign.declare(...)` — pulls escrow atomically.
 *   4. Spawn a job-mode Turbo pipeline to snapshot holders of `shareToken`
 *      from the share-token deploy block up to `recordBlock`. Per-campaign
 *      sink tables avoid cross-campaign aggregate contamination.
 *   5. Drive the campaign through snapshot → paying → complete inline,
 *      polling the pipeline at STATE_POLL_INTERVAL_MS until done. The
 *      whole lifecycle finishes in this single HTTP request.
 *
 * Idempotent on `campaignId`: a second POST with the same id resumes the
 * existing campaign (drives it forward if non-terminal) instead of
 * re-declaring.
 */
export async function main(context: TaskContext, params?: DeclareParams) {
  const { evm, collection } = context;
  if (!params) throw new Error("POST body required");

  const userId = params.campaignId;
  if (!isHexBytes32(userId)) {
    throw new Error("campaignId must be a 0x-prefixed 32-byte hex string");
  }
  if (typeof params.recordBlock !== "number" || params.recordBlock <= 0) {
    throw new Error("recordBlock must be a positive integer");
  }
  const totalAmount = BigInt(params.totalAmount);
  if (totalAmount <= 0n) throw new Error("totalAmount must be positive");

  const campaigns = await collection<Campaign>("campaigns", [
    { path: "status", type: "text" },
  ]);

  const rowId = userId.toLowerCase();
  const existing = await campaigns.getById(rowId);
  if (existing) {
    // Resume an in-flight campaign — keep driving it forward. Terminal
    // states (complete/failed) just return without doing anything.
    await driveCampaign(context, campaigns, existing);
    const fresh = (await campaigns.getById(rowId)) ?? existing;
    return responseFor(fresh, "resumed");
  }

  // --- recordBlock <= currentBlock ---
  // Resolved against the chain's public RPC via context.fetch (only fetch
  // path that's --allow-net'd in this child process).
  const chain = evm.chains[CONFIG.chain];
  const currentBlock = await getCurrentBlock(context, chain.rpcUrls.default.http[0]);
  const recordBlock = BigInt(params.recordBlock);
  if (recordBlock > currentBlock) {
    throw new Error(
      `recordBlock ${recordBlock} > currentBlock ${currentBlock}; ` +
        `future-dated record blocks are out of scope for this demo`,
    );
  }

  const wallet = await evm.wallet({
    name: "corp-actions-operator",
    sponsorGas: true,
  });

  // --- approve + declare on-chain ---
  await wallet.writeContract(
    chain,
    CONFIG.payToken,
    "approve(address,uint256)",
    [CONFIG.campaignContract, totalAmount.toString()],
  );

  const { hash } = await wallet.writeContract(
    chain,
    CONFIG.campaignContract,
    "declare(bytes32,address,address,uint256)",
    [userId, CONFIG.payToken, CONFIG.shareToken, totalAmount.toString()],
  );

  // canonicalId matches the contract's keccak256(operator, userId).
  const onChainId = keccak256(
    encodePacked(["address", "bytes32"], [wallet.address, userId as Hex]),
  );

  // --- spawn the snapshot pipeline ---
  // If this fails AFTER declare(), the operator can recover escrow with
  // DistributionCampaign.seal(). The campaign row is not written, so
  // there's nothing to drive forward.
  const pipeline = await createSnapshotPipeline(context, {
    campaignId: userId,
    shareToken: CONFIG.shareToken,
    recordBlock,
  });

  const campaign: Campaign = {
    rowId,
    userId: rowId as Hex,
    onChainId,
    shareToken: CONFIG.shareToken,
    payToken: CONFIG.payToken,
    totalAmount: totalAmount.toString(),
    recordBlock: recordBlock.toString(),
    declareTxHash: hash as Hex,
    pipelineName: pipeline.name,
    status: "snapshotting",
    createdAt: Date.now(),
  };
  await campaigns.setById(rowId, campaign);

  // Drive the campaign through snapshot → paying → complete inline. If
  // anything throws, the partial state is preserved and the operator can
  // re-POST the same campaignId to resume. Re-throw to surface failure.
  await driveCampaign(context, campaigns, campaign);
  const final = (await campaigns.getById(rowId)) ?? campaign;
  return responseFor(final, "declared");
}

function responseFor(c: Campaign, source: "declared" | "resumed") {
  return {
    status: c.status,
    source,
    userId: c.userId,
    onChainId: c.onChainId,
    pipelineName: c.pipelineName,
    declareTxHash: c.declareTxHash,
    failureReason: c.status === "failed" ? c.failureReason : undefined,
  };
}

async function getCurrentBlock(
  ctx: TaskContext,
  rpcUrl: string,
): Promise<bigint> {
  const res = await ctx.fetch<{ result?: string; error?: { message: string } }>(
    rpcUrl,
    {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: { jsonrpc: "2.0", id: 1, method: "eth_blockNumber", params: [] },
    },
  );
  if (res?.error) throw new Error(`eth_blockNumber: ${res.error.message}`);
  if (!res?.result) throw new Error("eth_blockNumber returned no result");
  return BigInt(res.result);
}
```

### `src/lib/constants.ts`

```typescript
import type { Hex } from "./types";

/**
 * Single-chain demo on Base Sepolia. Each declaration spawns its own
 * job-mode Turbo pipeline, so there's nothing chain-specific to configure
 * beyond the deployed contract addresses below.
 *
 * Defaults to Base Sepolia so the demo costs no real gas and uses the shared
 * permissionless contracts below (open mint on MockUSDC, open declare() on the
 * campaign). To run on Base mainnet instead, swap in these values (real gas
 * applies):
 *   chain: "base", turboChain: "base",
 *   shareToken:        "0xE05Ceb3E269029E3bab46E35515e8987060D1027",
 *   payToken (MockUSDC): "0x02D9Df62B7AED15739D638B92BAcEA2ce4Cb3d70",
 *   campaignContract:  "0x81051f77ea167b631Dd7F40ac414A9F9344Fb162",
 *   shareTokenDeployBlock: 45654954,
 *
 * Update after running `scripts/deploy.sh`.
 */
export const CONFIG = {
  chain:      "baseSepolia" as const,   // evm.chains[chain] key (camelCase)
  turboChain: "base_sepolia",           // Turbo dataset prefix (snake_case network slug)
  shareToken:       "0x713e0749a9Fe480322990913850e81b0F4F4dc0d" as Hex,
  payToken:         "0x8ec24F07F08745fc3D979336AA81d4Dc73f3D9DE" as Hex,  // MockUSDC (permissionless mint)
  campaignContract: "0xA8e58573B1e10908b63d12B603aCF9C784BF904E" as Hex,  // permissionless: anyone can declare()
  // Block at which `shareToken` was deployed. Job-mode forces
  // `start_at: earliest`, so we can't anchor the source there directly;
  // instead this is used as the lower bound in the snapshot pipeline's
  // SQL filter (`block_number BETWEEN <deploy> AND <record>`), which lets
  // the planner prune all pre-deploy blocks before scanning. Per Jeff: a
  // filter-level block range is meaningfully faster than a source-level
  // `end_block` alone.
  shareTokenDeployBlock: 42275958,
};

/**
 * Concurrent pay() calls. Bounded by the gas-sponsored bundler's throughput
 * (~1-5 userOps/sec/sender). Set high enough that the demo's full
 * 25-holder snapshot fires in a single batch.
 */
export const CONCURRENCY = 25;

/**
 * State-poll cadence while waiting for the Turbo job-mode snapshot to
 * finish. With Jeff's filter-level block range the snapshot finishes in
 * ~5-10s, so we poll fast (2s) so `declare_campaign` can drive the campaign
 * end-to-end inline before returning.
 */
export const STATE_POLL_INTERVAL_MS = 2_000;

/**
 * Hard cap on snapshot-poll iterations per drive call. Set high so we wait
 * out the snapshot in-line for any realistic case; pathological hangs still
 * eventually fall through to the cron path.
 */
export const MAX_POLLS_PER_TICK = 100;  // 100 × 2s = ~3.3 minutes

/**
 * The Turbo pipeline writes into per-campaign tables to avoid cross-campaign
 * SUM contamination in the `postgres_aggregate` sink.
 *
 *   share_balances_<id>      — agg table (account, balance)
 *   share_transfer_log_<id>  — landing table (truncated per checkpoint)
 *
 * `id` is a 16-char slice of campaignId — stable, unique, fits in Postgres'
 * 63-char identifier limit.
 */
export function pipelineId(campaignId: string): string {
  return campaignId.toLowerCase().replace(/^0x/, "").slice(0, 16);
}

export function pipelineName(campaignId: string): string {
  return `corp-actions-${pipelineId(campaignId)}`;
}

export function aggTableName(campaignId: string): string {
  return `share_balances_${pipelineId(campaignId)}`;
}
```

### `src/lib/types.ts`

```typescript
export type Hex = `0x${string}`;

/**
 * Campaign lifecycle:
 *
 *   snapshotting → paying → complete
 *                  ↘ failed
 *
 *   - snapshotting: a job-mode Turbo pipeline is running, indexing Transfer
 *     events of `shareToken` from chain genesis up to `recordBlock`.
 *   - paying: the pipeline has emitted the snapshot to Postgres; the cron is
 *     pro-rata paying out per holder.
 *   - complete: every holder is paid on-chain. Pipeline has been deleted.
 *   - failed: the pipeline errored. Pipeline has been deleted; the campaign
 *     row stays around for postmortem (escrow can be recovered via
 *     `DistributionCampaign.seal()`).
 */
export type CampaignStatus = "snapshotting" | "paying" | "complete" | "failed";

export interface DeclareParams {
  campaignId: string;   // bytes32 hex string — operator-supplied id
  recordBlock: number;  // snapshot point; must be <= chain head at declare time
  totalAmount: string;  // bigint as string (USDC has 6 decimals)
}

export interface Campaign {
  rowId: string;            // = userId (lowercased) — collection unique key
  userId: Hex;              // operator-supplied campaignId, lowercased
  onChainId: Hex;           // keccak256(operator, userId)
  shareToken: Hex;          // resolved server-side from constants
  payToken: Hex;            // resolved server-side (MockUSDC)
  totalAmount: string;
  recordBlock: string;      // snapshot block, recorded both on-chain and here
  declareTxHash: Hex;
  pipelineName: string;     // unique per campaign; used for /state polls and DELETE
  status: CampaignStatus;
  createdAt: number;
  snapshotCompletedAt?: number;
  completedAt?: number;
  failedAt?: number;
  failureReason?: string;
  // Persisted payouts so the holder/amount table survives terminalCleanup
  // (which drops the per-campaign Postgres tables). Populated when the
  // driver transitions to "paying" and the pro-rata is computed; bigints
  // serialised as decimal strings so the row round-trips through JSON.
  payouts?: PersistedPayout[];
}

export interface PersistedPayout {
  holder: Hex;
  sharesAtSnapshot: string;  // bigint as text
  amount: string;            // bigint as text (USDC, 6 decimals)
  payTxHash?: Hex;           // captured per-batch in drivePayouts
}

export interface Holder {
  address: Hex;
  balance: bigint;
}

export interface Payout {
  holder: Hex;
  amount: bigint;
  sharesAtSnapshot: bigint;
}
```

### `src/lib/math.ts`

```typescript
import type { Holder, Payout } from "./types";
import { normalizeAddr } from "./normalize";

/**
 * Pro-rata payout calculator.
 *
 * Integer division floors each holder's share, leaving a remainder. To make the
 * sum equal `totalAmount` exactly, the remainder is added to the LAST holder's
 * payout. This rounding direction is documented and stable: holders are sorted
 * by address ascending so "last" is deterministic across runs.
 *
 * @param holders     non-empty list of holders with bigint balances
 * @param totalAmount total escrow to distribute (bigint)
 * @param totalSupply sum of all holder balances (bigint)
 */
export function proRata(
  holders: Holder[],
  totalAmount: bigint,
  totalSupply: bigint,
): Payout[] {
  if (holders.length === 0) return [];
  if (totalSupply === 0n) {
    throw new Error("totalSupply must be positive");
  }

  // Sort by address ascending so "last holder" is deterministic.
  const sorted = [...holders].sort((a, b) =>
    a.address.toLowerCase() < b.address.toLowerCase() ? -1 : 1,
  );

  const payouts: Payout[] = [];
  let allocated = 0n;
  for (let i = 0; i < sorted.length; i++) {
    const h = sorted[i];
    const isLast = i === sorted.length - 1;
    const amount = isLast
      ? totalAmount - allocated // last holder absorbs floor remainder
      : (h.balance * totalAmount) / totalSupply;
    payouts.push({
      holder: normalizeAddr(h.address),
      amount,
      sharesAtSnapshot: h.balance,
    });
    allocated += amount;
  }
  return payouts;
}
```

### `src/lib/normalize.ts`

```typescript
import type { Hex } from "./types";

const BYTES32_RE = /^0x[a-fA-F0-9]{64}$/;
const ADDR_RE = /^0x[a-fA-F0-9]{40}$/;

/**
 * Normalize an EVM address to lowercase 0x-hex.
 * Apply at every boundary: Postgres reads, collection keys, contract args.
 */
export function normalizeAddr(s: string): Hex {
  if (!ADDR_RE.test(s)) {
    throw new Error(`invalid address: ${s}`);
  }
  return s.toLowerCase() as Hex;
}

export function isHexBytes32(s: string): boolean {
  return BYTES32_RE.test(s);
}
```

### `src/lib/db.ts`

```typescript
import type { TaskContext } from "compose";
import type { Hex, Holder } from "./types";

/**
 * Query Neon's HTTP `/sql` endpoint via compose's IPC-routed `context.fetch`.
 *
 * Why not the `@neondatabase/serverless` driver?
 *   The compose-task child process is compiled WITHOUT `--allow-net`. Raw TCP
 *   AND `globalThis.fetch` from the task code both error with `EPERM`. The ONLY
 *   permitted egress path is `context.fetch`, which IPCs into the host process
 *   (which has `--allow-net`).
 *
 * `POSTGRES_CONNECTION_STRING` is auto-injected by compose-cloud. The Turbo
 * job-mode pipelines that this app spawns write into the same Neon DB via
 * the auto-created `CORPORATE_ACTIONS` project secret.
 */

interface NeonRow {
  [key: string]: string | number | boolean | null;
}
interface NeonResponse {
  rows?: NeonRow[];
}

function getConnectionString(): string {
  const url = Deno.env.get("POSTGRES_CONNECTION_STRING");
  if (!url) {
    throw new Error("POSTGRES_CONNECTION_STRING not set");
  }
  // Tack on params that bust Neon pool stickiness:
  //   - target_session_attrs=read-write → routes to primary, not a replica
  //   - application_name=<unique>      → defeats pool slot stickiness so each
  //                                      HTTP query gets a freshly-spawned
  //                                      backend connection (which sees
  //                                      committed writes, not a stale snapshot)
  // We've measured ~145s read lag without these; with them the read should
  // see writes within seconds.
  const u = new URL(url);
  u.searchParams.set("target_session_attrs", "read-write");
  u.searchParams.set(
    "application_name",
    `corp-actions-${Date.now()}-${Math.random().toString(36).slice(2, 8)}`,
  );
  return u.toString();
}

/** Derive Neon's HTTP `/sql` URL from a Postgres connection string. */
function neonHttpUrl(connStr: string): string {
  const u = new URL(connStr);
  // Use hostname (not host) so we drop the :5432 postgres port; HTTPS goes
  // to 443. Replace the first dotted segment with "api." per the official
  // @neondatabase/serverless transformation.
  const apiHost = u.hostname.replace(/^[^.]+\./, "api.");
  return `https://${apiHost}/sql`;
}

export async function neonQuery(
  ctx: TaskContext,
  query: string,
  params: unknown[] = [],
): Promise<NeonRow[]> {
  const connStr = getConnectionString();
  const url = neonHttpUrl(connStr);
  const res = await ctx.fetch<NeonResponse>(url, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "Neon-Connection-String": connStr,
      "Neon-Raw-Text-Output": "true",
      "Neon-Array-Mode": "false",
    },
    body: { query, params },
  });
  return res?.rows ?? [];
}

/**
 * Compute holder balances for a campaign's snapshot.
 *
 * Each campaign's pipeline writes raw Transfer rows to its own
 * `share_balances_<id>` table (no in-pipeline aggregation — see the rant in
 * `lib/turbo.ts` about FixedSizeBinary handling). The aggregate runs here
 * as a Postgres SQL: every transfer credits the recipient and debits the
 * sender (skipping the zero-address sender for mints), summed per account.
 *
 * Postgres handles binary→numeric coercion at write time — `amount` lands
 * as `numeric(78,0)` which we can cast to text and parse as a JS bigint
 * without precision loss.
 */
export async function getHolders(
  ctx: TaskContext,
  table: string,
): Promise<Holder[]> {
  // `table` is a constructed identifier from pipelineId() — alphanumeric +
  // underscore only — so direct interpolation is safe. (Postgres prepared
  // statements don't support parameterising table names anyway.)
  const rows = await neonQuery(
    ctx,
    `SELECT account, SUM(delta)::text AS balance
       FROM (
         SELECT lower(recipient) AS account, amount AS delta
           FROM "${table}"
         UNION ALL
         SELECT lower(sender) AS account, -amount AS delta
           FROM "${table}"
          WHERE lower(sender) != '0x0000000000000000000000000000000000000000'
       ) ledger
      GROUP BY account
     HAVING SUM(delta) > 0
      ORDER BY account ASC`,
  );
  return rows.map((r) => ({
    address: String(r.account).toLowerCase() as Hex,
    balance: BigInt(String(r.balance)),
  }));
}

/**
 * Number of Transfer rows in the per-campaign table, or `null` if the table
 * doesn't exist yet.
 *
 * Why count rather than just check existence?
 *   The Postgres sink creates the table on the very first checkpoint —
 *   even an "empty epoch" with zero matching rows commits, which creates
 *   the schema. So `aggTableExists` can return `true` while the pipeline
 *   is still mid-scan and hasn't reached blocks where the share token's
 *   Transfers live. Counting rows distinguishes "sink initialized" from
 *   "sink has actually delivered data".
 */
export async function aggTableRowCount(
  ctx: TaskContext,
  aggTable: string,
): Promise<number | null> {
  // Beefy diagnostic version: schema-qualified count, planner-stat count,
  // physical table size, schema list, and connection identity. Designed
  // to triangulate a Neon read-after-write visibility lag we've been
  // seeing where count(*) returns 0 for ~2 minutes after the pipeline
  // commits ~10 rows.
  try {
    const diag = await neonQuery(
      ctx,
      `SELECT
         (SELECT count(*)::text FROM public."${aggTable}") AS n_public,
         (SELECT pg_table_size('public."${aggTable}"')::text) AS bytes,
         pg_is_in_recovery()::text AS in_recovery,
         pg_last_xact_replay_timestamp()::text AS last_replay,
         now()::text AS now_ts,
         (SELECT EXTRACT(epoch FROM (now() - pg_last_xact_replay_timestamp()))::text) AS replay_lag_s,
         pg_backend_pid()::text AS pid,
         (SELECT setting FROM pg_settings WHERE name = 'application_name') AS app_name`,
    );
    const r = diag[0] ?? {};
    const n = Number(r.n_public ?? 0);
    console.log(
      `[db] "${aggTable}" n=${r.n_public} bytes=${r.bytes} ` +
        `recovery=${r.in_recovery} replay_lag_s=${r.replay_lag_s} ` +
        `last_replay=${r.last_replay} now=${r.now_ts} ` +
        `pid=${r.pid} app=${r.app_name}`,
    );
    return n;
  } catch (err) {
    const msg = err instanceof Error ? err.message : String(err);
    if (/does not exist|undefined.relation|relation .* does not exist/i.test(msg)) {
      console.log(`[db] "${aggTable}" → table missing`);
      return null;
    }
    console.log(`[db] "${aggTable}" threw: ${msg}`);
    throw err;
  }
}

/**
 * Drop the per-campaign table. Called on terminal cleanup so the user's
 * Neon DB doesn't accumulate orphaned tables across many campaigns.
 *
 * MUST be called AFTER the pipeline has been DELETE-ed — Turbo's sink writer
 * holds a connection, and dropping while it's still active is racing.
 */
export async function dropCampaignTables(
  ctx: TaskContext,
  transfersTable: string,
): Promise<void> {
  await neonQuery(ctx, `DROP TABLE IF EXISTS "${transfersTable}"`);
}
```

### `src/lib/driver.ts`

```typescript
import type { TaskContext } from "compose";

import {
  aggTableName,
  CONCURRENCY,
  CONFIG,
  MAX_POLLS_PER_TICK,
  STATE_POLL_INTERVAL_MS,
} from "./constants";
import { aggTableRowCount, dropCampaignTables, getHolders } from "./db";
import { proRata } from "./math";
import { deletePipeline, getPipelineState } from "./turbo";
import type { Campaign, Payout, PersistedPayout } from "./types";

/**
 * Drive a single campaign through the snapshot → paying → complete state
 * machine. Called inline by declare_campaign; can be called repeatedly to
 * resume a stuck campaign.
 *
 *   - status="snapshotting": poll the campaign's job-mode pipeline state at
 *     STATE_POLL_INTERVAL_MS up to MAX_POLLS_PER_TICK iterations until it
 *     transitions to `completed` (or its k8s deployment auto-cleans up
 *     after a successful run, which we infer from `unknown` + agg table
 *     having rows). On `error` → flip to "failed", drop the per-campaign
 *     tables, delete the pipeline.
 *
 *   - status="paying": read the snapshot from the per-campaign agg table,
 *     compute pro-rata, pay each holder via DistributionCampaign.pay() with
 *     bounded concurrency. The contract's `paid[id][holder]` mapping is the
 *     sole source of truth for "did this holder get paid?" — re-read on
 *     every drive call, so a pod kill mid-batch is recovered cleanly.
 *     When `escrowRemaining == 0` → mark complete, delete pipeline,
 *     drop tables.
 *
 *   - status="complete" or "failed": no-op. Terminal.
 */
export async function driveCampaign(
  context: TaskContext,
  campaigns: Awaited<ReturnType<TaskContext["collection"]>>,
  campaign: Campaign,
) {
  if (campaign.status === "snapshotting") {
    await driveSnapshot(context, campaigns, campaign);
    return;
  }
  if (campaign.status === "paying") {
    await drivePayouts(context, campaigns, campaign);
    return;
  }
}

async function driveSnapshot(
  context: TaskContext,
  campaigns: Awaited<ReturnType<TaskContext["collection"]>>,
  campaign: Campaign,
) {
  const aggTable = aggTableName(campaign.userId);

  for (let i = 0; i < MAX_POLLS_PER_TICK; i++) {
    const state = await getPipelineState(context, campaign.pipelineName);

    if (state === "error") {
      await markFailed(
        context,
        campaigns,
        campaign,
        "pipeline entered error state",
      );
      return;
    }

    // The Postgres sink commits the table on its FIRST checkpoint — even
    // an empty epoch creates the schema. So we have to count rows, not
    // just check the table exists, or a brief `/state` 404 mid-scan can
    // race the driver into transitioning to `paying` while the pipeline
    // is still scanning ahead of the share token's deploy block.
    //
    // Two paths to "snapshot ready":
    //   1. Pipeline reports completed/paused/stopped AND the table has
    //      ≥1 row.
    //   2. Pipeline state is `unknown` (404 from the auto-cleanup path
    //      that follows a successful job-mode run) AND the table has
    //      ≥1 row.
    //
    // If state is terminal but the table is empty, that's a structural
    // failure (or a token with no holders, which for a corp-action is
    // also operationally a failure).
    const rowCount = await aggTableRowCount(context, aggTable);
    console.log(
      `[${campaign.userId}] poll i=${i} state=${state} rowCount=${rowCount}`,
    );
    const sawTerminalState = state === "completed";

    if (sawTerminalState && (rowCount === null || rowCount === 0)) {
      await markFailed(
        context,
        campaigns,
        campaign,
        `pipeline completed but ${aggTable} has no rows ` +
          `(token may have no transfers, or pipeline failed silently)`,
      );
      return;
    }

    const haveRows = rowCount !== null && rowCount > 0;
    const looksAutoCleaned = state === "unknown" && haveRows;

    if ((sawTerminalState && haveRows) || looksAutoCleaned) {
      console.log(`[${campaign.userId}] snapshot completed → paying`);
      const updated: Campaign = {
        ...campaign,
        status: "paying",
        snapshotCompletedAt: Date.now(),
      };
      await campaigns.setById(campaign.rowId, updated);
      // Don't re-read from the collection here — same Neon pool-stickiness
      // bug we hit on user tables means setById's write may not be visible
      // to an immediate getById on the same connection. We have the new
      // value in-memory; pass it through directly.
      await drivePayouts(context, campaigns, updated);
      return;
    }

    // running / starting / unknown-without-rows → keep waiting
    if (i < MAX_POLLS_PER_TICK - 1) {
      await sleep(STATE_POLL_INTERVAL_MS);
    }
  }
  console.log(
    `[${campaign.userId}] snapshot still in-flight after ${MAX_POLLS_PER_TICK} polls; ` +
      `re-call declare_campaign with the same id to resume`,
  );
}

async function drivePayouts(
  context: TaskContext,
  campaigns: Awaited<ReturnType<TaskContext["collection"]>>,
  campaign: Campaign,
) {
  console.log(`[${campaign.userId}] drivePayouts: start`);
  const aggTable = aggTableName(campaign.userId);
  const holders = await getHolders(context, aggTable);
  console.log(`[${campaign.userId}] drivePayouts: holders=${holders.length}`);
  if (holders.length === 0) {
    // The snapshot completed (the agg table exists) but contains zero rows.
    // For a corporate-action distribution this is always a failure — either
    // the pipeline pod silently failed before writing data, or the operator
    // declared against a token with no holders. Surface it; the operator can
    // recover escrow via DistributionCampaign.seal().
    await markFailed(
      context,
      campaigns,
      campaign,
      "snapshot returned 0 holders (pipeline may have failed to index)",
    );
    return;
  }

  const totalSupply = holders.reduce((s, h) => s + h.balance, 0n);
  const payouts = proRata(holders, BigInt(campaign.totalAmount), totalSupply);

  // Persist payouts onto the campaign row so the holder/amount table
  // survives terminalCleanup (which drops the per-campaign Postgres
  // table). Useful for audit + for operator UIs reading campaign state
  // after the per-campaign tables have been cleaned up.
  if (!campaign.payouts) {
    const persisted: PersistedPayout[] = payouts.map((p) => ({
      holder: p.holder,
      sharesAtSnapshot: p.sharesAtSnapshot.toString(),
      amount: p.amount.toString(),
    }));
    campaign.payouts = persisted;
    await campaigns.setById(campaign.rowId, campaign);
  }

  const wallet = await context.evm.wallet({
    name: "corp-actions-operator",
    sponsorGas: true,
  });
  const chain = context.evm.chains[CONFIG.chain];

  // Filter to unpaid holders by reading on-chain state. The contract is the
  // sole source of truth — if the pod was killed mid-batch on a previous
  // call, the already-paid holders show up here as paid and we skip them.
  const unpaid: Payout[] = [];
  for (const p of payouts) {
    const isAlreadyPaid = await wallet.readContract(
      chain,
      CONFIG.campaignContract,
      "isPaid(bytes32,address)",
      [campaign.onChainId, p.holder],
    );
    if (!isAlreadyPaid) unpaid.push(p);
  }

  console.log(
    `[${campaign.userId}] drivePayouts: unpaid=${unpaid.length}/${payouts.length}`,
  );
  if (unpaid.length === 0) {
    await maybeMarkComplete(context, campaigns, campaign, payouts);
    return;
  }

  // Bounded concurrency. Promise.allSettled so one revert doesn't break the
  // whole batch — the contract's `AlreadyPaid` guard means duplicates are
  // safe even when we're optimistic about parallel state.
  const txByHolder = new Map<string, string>();
  for (let i = 0; i < unpaid.length; i += CONCURRENCY) {
    const batch = unpaid.slice(i, i + CONCURRENCY);
    console.log(`[${campaign.userId}] drivePayouts: sending batch ${batch.length}`);
    const results = await Promise.allSettled(
      batch.map((p) => payOne(wallet, chain, campaign, p)),
    );
    results.forEach((res, idx) => {
      if (res.status === "fulfilled" && res.value) {
        txByHolder.set(batch[idx].holder.toLowerCase(), res.value);
      }
    });
  }

  // Stitch tx hashes back into the persisted payouts so audit tooling
  // can deep-link each holder row to the actual pay() tx on basescan.
  if (txByHolder.size && campaign.payouts) {
    let mutated = false;
    for (const p of campaign.payouts) {
      const tx = txByHolder.get(p.holder.toLowerCase());
      if (tx && !p.payTxHash) {
        p.payTxHash = tx as `0x${string}`;
        mutated = true;
      }
    }
    if (mutated) await campaigns.setById(campaign.rowId, campaign);
  }

  console.log(`[${campaign.userId}] drivePayouts: batches done, checking escrow`);
  // Re-read on-chain state to decide if we're done.
  await maybeMarkComplete(context, campaigns, campaign, payouts);
}

async function payOne(
  wallet: Awaited<ReturnType<TaskContext["evm"]["wallet"]>>,
  chain: TaskContext["evm"]["chains"][keyof TaskContext["evm"]["chains"]],
  campaign: Campaign,
  { holder, amount, sharesAtSnapshot }: Payout,
): Promise<string | null> {
  try {
    const { hash } = await wallet.writeContract(
      chain,
      CONFIG.campaignContract,
      "pay(bytes32,address,uint256,uint256)",
      [
        campaign.onChainId,
        holder,
        amount.toString(),
        sharesAtSnapshot.toString(),
      ],
    );
    return hash;
  } catch (err) {
    const msg = err instanceof Error ? err.message : String(err);
    if (/AlreadyPaid/.test(msg)) return null;       // contract guard absorbed a race
    if (/AlreadySealed|InsufficientEscrow/.test(msg)) {
      console.log(`[${campaign.userId}] terminal pay failure for ${holder}: ${msg}`);
      return null;
    }
    console.log(`[${campaign.userId}] transient pay failure for ${holder}: ${msg}`);
    return null;
  }
}

async function maybeMarkComplete(
  context: TaskContext,
  campaigns: Awaited<ReturnType<TaskContext["collection"]>>,
  campaign: Campaign,
  payouts: Payout[],
) {
  if (campaign.status === "complete") return;

  // Source of truth for "is this campaign fully distributed" is the
  // contract's `escrowRemaining`. A single read, atomic.
  //
  // The previous implementation looped N `isPaid()` reads instead — which
  // looked correct but had a real failure mode: with sponsored gas + a
  // cluster of pay() txs, individual RPC nodes can return a stale `false`
  // for an isPaid that's actually true on chain. One stale read kept the
  // campaign in `paying` forever and re-fired pay() (silently absorbed by
  // the AlreadyPaid guard, but noisy in operator logs). escrowRemaining=0
  // is a single signal that's already resolved by the contract's
  // checks-effects-interactions on every pay().
  const wallet = await context.evm.wallet({
    name: "corp-actions-operator",
    sponsorGas: true,
  });
  const chain = context.evm.chains[CONFIG.chain];
  const c = await wallet.readContract<
    readonly [
      `0x${string}`, `0x${string}`, `0x${string}`,
      bigint, bigint, bigint,
      boolean, boolean,
    ]
  >(
    chain,
    CONFIG.campaignContract,
    "campaigns(bytes32) view returns (address,address,address,uint256,uint256,uint256,bool,bool)",
    [campaign.onChainId],
  );
  const escrowRemaining = c[4];
  console.log(
    `[${campaign.userId}] maybeMarkComplete: escrowRemaining=${escrowRemaining}`,
  );
  if (escrowRemaining > 0n) return; // not done; caller can re-drive to keep paying

  await terminalCleanup(context, campaign);
  await campaigns.setById(campaign.rowId, {
    ...campaign,
    status: "complete",
    completedAt: Date.now(),
  });
  console.log(`[${campaign.userId}] complete: paid ${payouts.length} holders`);
}

async function markFailed(
  context: TaskContext,
  campaigns: Awaited<ReturnType<TaskContext["collection"]>>,
  campaign: Campaign,
  reason: string,
) {
  await terminalCleanup(context, campaign);
  await campaigns.setById(campaign.rowId, {
    ...campaign,
    status: "failed",
    failedAt: Date.now(),
    failureReason: reason,
  });
  console.log(`[${campaign.userId}] failed: ${reason}`);
}

/**
 * Belt-and-suspenders cleanup. Turbo auto-deletes successful job-mode
 * pipelines ~1h after completion, but errored jobs stay around forever
 * unless we DELETE them. We always run both regardless of terminal status
 * so the user's account stays clean across many demo runs.
 *
 * Order matters: DELETE the pipeline first (releases the sink writer's
 * connection), THEN drop the tables.
 */
async function terminalCleanup(context: TaskContext, campaign: Campaign) {
  await deletePipeline(context, campaign.pipelineName).catch(() => {});
  const transfers = aggTableName(campaign.userId);
  await dropCampaignTables(context, transfers).catch(() => {});
}

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}
```

### `src/lib/turbo.ts`

```typescript
import type { TaskContext } from "compose";
import {
  aggTableName,
  CONFIG,
  pipelineName,
} from "./constants";
import type { Hex } from "./types";

/**
 * HTTP client for Goldsky's Turbo pipeline API. Same endpoints the `goldsky`
 * CLI uses, talking directly to api.goldsky.com over public ingress (the
 * compose pod has outbound network for this).
 *
 * Auth is a project API token surfaced as `context.env.GOLDSKY_PROJECT_KEY`
 * — declared in compose.yaml's `secrets:` block, set once via
 * `goldsky compose secret set GOLDSKY_PROJECT_KEY --value "$GOLDSKY_PROJECT_KEY"`.
 */

const API_BASE = "https://api.goldsky.com/api/v1";

function authHeaders(env: Record<string, string>): Record<string, string> {
  const key = env.GOLDSKY_PROJECT_KEY;
  if (!key) {
    throw new Error(
      "GOLDSKY_PROJECT_KEY missing — declare it under `secrets:` in compose.yaml " +
        "and set its value with `goldsky compose secret set GOLDSKY_PROJECT_KEY`",
    );
  }
  return {
    Authorization: `Bearer ${key}`,
    "Content-Type": "application/json",
  };
}

export type TurboState =
  | "running"
  | "starting"
  | "paused"
  | "stopped"
  | "error"
  | "completed"
  | "unknown";

interface StateResponse {
  status?: string;
  state?: string;
  errors?: unknown;
  success?: boolean;
  error?: string;
}

/**
 * Build the job-mode pipeline definition that snapshots holders of a single
 * ERC-20 at a specific block.
 *
 * Why `erc20_transfers` and not `logs`?
 *   `job: true` requires every source to be a "hybrid source" (one that
 *   supports a bounded backfill). On Base mainnet, `logs` is NOT hybrid;
 *   `erc20_transfers` is. (Pipeline that tried `base.logs` failed with
 *   `job_mode is enabled but the following source(s) do not support it`.)
 *
 * Why `to_u256(amount)` before the cast?
 *   `erc20_transfers.amount` is `FixedSizeBinary(32)` and DataFusion has no
 *   direct cast from FixedSizeBinary to DOUBLE/DECIMAL. `to_u256` is the
 *   canonical bridge — it returns a numeric type that casts cleanly.
 *   (See the failing `corp-actions-5a06330a7f49ce61` pod which tripped on
 *   `Unsupported CAST from FixedSizeBinary(32) to Float64`.)
 *
 * Pieces:
 *   - source: `base.erc20_transfers` with `start_at: earliest` (required for
 *     hybrid-source / job-mode), narrowed by a filter that bounds both ends
 *     of the scan: `lower(address) = <token> AND block_number BETWEEN
 *     <deployBlock> AND <recordBlock>`. Per Jeff: a filter-level lower+upper
 *     block range is dramatically faster than a source-level `end_block`
 *     because the planner can prune partitions/files before scanning.
 *   - transform: split each Transfer into `+amount` at `recipient` and
 *     `-amount` at `sender` (skip zero-address sender for mints)
 *   - sink: postgres_aggregate sums per-account deltas into a per-campaign
 *     agg table so concurrent campaigns can't collide on SUM
 */
export function buildSnapshotPipeline(input: {
  campaignId: string;
  shareToken: Hex;
  recordBlock: bigint;
}): Record<string, unknown> {
  const transfersTable = aggTableName(input.campaignId);
  const tokenLower = input.shareToken.toLowerCase();
  const startBlock = CONFIG.shareTokenDeployBlock;
  const endBlock = Number(input.recordBlock);

  return {
    resource_size: "s",
    job: true,
    sources: {
      transfers: {
        type: "dataset",
        dataset_name: `${CONFIG.turboChain}.erc20_transfers`,
        version: "1.2.0",
        // `start_at` MUST be 'earliest' for hybrid-source / job-mode
        // semantics. Setting it to a block number makes the source
        // non-hybrid and Turbo refuses to run with job:true. The
        // block-range filter below carries the actual scan bounds.
        start_at: "earliest",
        filter:
          `lower(address) = '${tokenLower}' ` +
          `AND block_number BETWEEN ${startBlock} AND ${endBlock}`,
      },
    },
    // The v1 pipelines API requires a `transforms` object even when there's
    // nothing to do — leave it empty.
    transforms: {},
    // Why no SQL transform?
    //   We tried — extensively. `amount` arrives as `FixedSizeBinary(32)` at
    //   the DataFusion layer and there is no in-pipeline conversion to a
    //   numeric/decimal that the planner accepts. Every UDF route either
    //   silently passes binary through (invalid Utf8 downstream),
    //   misinterprets hex as decimal, or hits "Unsupported CAST from
    //   FixedSizeBinary(32) to <T>". The Postgres sink, however, has its
    //   own binary→numeric mapping. So we sink the raw Transfer rows and
    //   compute balances via a SQL aggregate over Postgres at read time
    //   (see `getHolders` in lib/db.ts). One more network round-trip per
    //   campaign in exchange for not fighting DataFusion.
    sinks: {
      transfers_sink: {
        type: "postgres",
        from: "transfers",
        schema: "public",
        table: transfersTable,
        primary_key: "id",
        secret_name: "CORPORATE_ACTIONS",
      },
    },
  };
}

export async function createSnapshotPipeline(
  ctx: TaskContext,
  input: {
    campaignId: string;
    shareToken: Hex;
    recordBlock: bigint;
  },
): Promise<{ name: string }> {
  const name = pipelineName(input.campaignId);
  const definition = buildSnapshotPipeline(input);

  const body = {
    name,
    resource_size: "s",
    description: `Holder snapshot for campaign ${input.campaignId} at block ${input.recordBlock}`,
    definition,
  };

  console.log(
    `[turbo] POST /pipelines: name=${name}, ` +
      `block_range=[${CONFIG.shareTokenDeployBlock}, ${input.recordBlock}]`,
  );
  try {
    const res = await ctx.fetch(`${API_BASE}/pipelines`, {
      method: "POST",
      headers: authHeaders(ctx.env),
      body,
    });
    console.log(`[turbo] POST /pipelines response: ${JSON.stringify(res).slice(0, 500)}`);
  } catch (err) {
    const msg = err instanceof Error ? err.message : String(err);
    console.log(`[turbo] POST /pipelines threw: ${msg}`);
    throw err;
  }
  return { name };
}

/**
 * Read raw upstream pipeline state.
 *
 * NB: we use `/state` (proxied unchanged from streamling) NOT `/status`. The
 * v1 `/status` endpoint runs a status normalizer that maps `completed` →
 * `"UNKNOWN"`, which would silently break job-mode termination detection.
 */
export async function getPipelineState(
  ctx: TaskContext,
  name: string,
): Promise<TurboState> {
  try {
    // Use `/state` (proxied to streamling-agent) NOT `/pipelines/<name>` or
    // `/status` — those return CACHED registry data that lags k8s by minutes
    // (or forever for job-mode pipelines that were cleaned up). `/state`
    // queries the actual k8s deployment, so it's the only reliable source
    // for "did the pipeline finish".
    const res = await ctx.fetch<StateResponse>(
      `${API_BASE}/pipelines/${encodeURIComponent(name)}/state`,
      { method: "GET", headers: authHeaders(ctx.env) },
    );

    // streamling-agent returns `{success: false, error: "...not found"}`
    // when the k8s deployment is gone — which for a job-mode pipeline means
    // it completed and was cleaned up. The caller (driveSnapshot) treats
    // this as "unknown" + uses the per-campaign table's row count as the
    // actual success signal.
    if (res?.success === false) {
      const errMsg = String(res?.error ?? "").toLowerCase();
      if (/not found|missing|deployments?\b/i.test(errMsg)) return "unknown";
    }

    const raw = (res?.status ?? res?.state ?? "unknown").toString().toLowerCase();
    console.log(`[turbo] /state(${name}) raw=${raw}`);
    if (
      raw === "completed" || raw === "complete" ||
      raw === "succeeded" || raw === "success" ||
      raw === "finished" ||
      raw === "paused" || raw === "stopped"
    ) {
      return "completed";
    }
    if (raw === "running" || raw === "starting" || raw === "deploying") {
      return "running";
    }
    if (raw === "error" || raw === "failed") return "error";
    return "unknown";
  } catch (err) {
    const msg = err instanceof Error ? err.message : String(err);
    // Direct 404 (pipeline registry entry has been deleted) — same as the
    // "deployment not found" case above: treat as unknown, let the caller
    // decide based on the table contents.
    if (/404|not found/i.test(msg)) return "unknown";
    throw err;
  }
}

export async function deletePipeline(
  ctx: TaskContext,
  name: string,
): Promise<void> {
  try {
    await ctx.fetch(
      `${API_BASE}/pipelines/${encodeURIComponent(name)}`,
      { method: "DELETE", headers: authHeaders(ctx.env) },
    );
  } catch (err) {
    const msg = err instanceof Error ? err.message : String(err);
    // Idempotent: a 404 just means the pipeline was already cleaned up. Any
    // other error is real and the caller should know about it.
    if (!/404|not found/i.test(msg)) throw err;
  }
}
```

### `contracts/DistributionCampaign.sol`

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address to, uint256 value) external returns (bool);
    function transferFrom(address from, address to, uint256 value) external returns (bool);
}

/**
 * @title DistributionCampaign
 * @notice On-chain audit-trail + double-pay guard for tokenized corporate-action distributions
 *         (dividends, coupons, rebates, rewards). Operator-supplied per-holder amounts; the
 *         contract enforces escrow caps and one-time payment per holder.
 *
 * @dev Many campaigns can coexist in a single deployed instance; each is keyed by a canonical
 *      `id = keccak256(operator, userId)` to namespace user-supplied IDs across operators.
 *
 *      Reverts use string `require` messages (not custom errors) so off-chain callers can
 *      decode them via the standard `Error(string)` selector.
 *
 *      Demo-grade. Not audited. Anyone can `declare()` a campaign with their own funds; the
 *      operator address is recorded and only the operator can `pay()` or `seal()` that campaign.
 */
contract DistributionCampaign {
    struct Campaign {
        address operator;        // wallet that called declare(); only caller for pay/seal
        address payToken;        // ERC-20 used for payouts (e.g. MockUSDC)
        address shareToken;      // tokenized equity reference (informational; for audit reconciliation)
        uint256 totalAmount;     // initial escrow pulled from operator at declare time
        uint256 escrowRemaining; // decremented per pay(); refunded on seal()
        uint256 recordBlock;     // snapshot block at declare time (audit reference)
        bool    declared;        // set on declare; prevents re-declare under same id
        bool    sealed_;         // terminal; no more pay() allowed
    }

    /// @notice campaigns[canonicalId]
    mapping(bytes32 => Campaign) public campaigns;

    /// @notice paid[canonicalId][holder] = amount (0 means unpaid)
    mapping(bytes32 => mapping(address => uint256)) public paid;

    event CampaignDeclared(
        bytes32 indexed id,
        address indexed operator,
        address payToken,
        address shareToken,
        uint256 totalAmount,
        uint256 recordBlock
    );
    event HolderPaid(
        bytes32 indexed id,
        address indexed holder,
        address payToken,         // included so auditors don't need a separate getCampaign call
        uint256 amount,
        uint256 sharesAtSnapshot  // operator-supplied; lets auditors recompute pro-rata independently
    );
    event CampaignSealed(bytes32 indexed id, uint256 refunded);

    /// @notice Derive canonical id from operator + user-supplied id. Anyone can call this view to
    ///         compute the id off-chain before tx submission.
    function canonicalId(address operator, bytes32 userId) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(operator, userId));
    }

    /// @notice Open a new campaign. Pulls `totalAmount` of `payToken` from msg.sender atomically.
    ///         The record block is `block.number` of the declare tx — the off-chain indexer
    ///         must wait for that block + finality depth before reading the snapshot.
    /// @param userId      operator-supplied identifier; canonical id = keccak256(operator, userId)
    /// @param payToken    ERC-20 used for payouts
    /// @param shareToken  reference share token (informational; recorded in events)
    /// @param totalAmount total escrow to pull from msg.sender via transferFrom
    /// @return id         canonical id
    function declare(
        bytes32 userId,
        address payToken,
        address shareToken,
        uint256 totalAmount
    ) external returns (bytes32 id) {
        id = canonicalId(msg.sender, userId);
        Campaign storage c = campaigns[id];
        require(!c.declared, "AlreadyDeclared");
        require(totalAmount > 0, "ZeroAmount");

        c.operator = msg.sender;
        c.payToken = payToken;
        c.shareToken = shareToken;
        c.totalAmount = totalAmount;
        c.escrowRemaining = totalAmount;
        c.recordBlock = block.number;
        c.declared = true;

        require(IERC20(payToken).transferFrom(msg.sender, address(this), totalAmount), "TransferFromFailed");

        emit CampaignDeclared(id, msg.sender, payToken, shareToken, totalAmount, block.number);
    }

    /// @notice Pay one holder for one campaign. Idempotent — reverts `AlreadyPaid` on duplicate.
    /// @dev Strict checks-effects-interactions: paid[] and escrowRemaining are updated BEFORE the
    ///      external transfer to defeat any reentrancy hook in a swapped-in pay token.
    function pay(
        bytes32 id,
        address holder,
        uint256 amount,
        uint256 sharesAtSnapshot
    ) external {
        Campaign storage c = campaigns[id];
        require(c.declared, "NotDeclared");
        require(!c.sealed_, "AlreadySealed");
        require(msg.sender == c.operator, "NotOperator");
        require(paid[id][holder] == 0, "AlreadyPaid");
        require(c.escrowRemaining >= amount, "InsufficientEscrow");
        require(amount > 0, "ZeroAmount");

        // Effects
        paid[id][holder] = amount;
        c.escrowRemaining -= amount;

        // Interaction
        require(IERC20(c.payToken).transfer(holder, amount), "TransferFailed");

        emit HolderPaid(id, holder, c.payToken, amount, sharesAtSnapshot);
    }

    /// @notice Close out a campaign and return any unpaid escrow to the operator.
    function seal(bytes32 id) external {
        Campaign storage c = campaigns[id];
        require(c.declared, "NotDeclared");
        require(!c.sealed_, "AlreadySealed");
        require(msg.sender == c.operator, "NotOperator");

        uint256 refund = c.escrowRemaining;
        c.escrowRemaining = 0;
        c.sealed_ = true;

        if (refund > 0) {
            require(IERC20(c.payToken).transfer(c.operator, refund), "TransferFailed");
        }
        emit CampaignSealed(id, refund);
    }

    /// @notice Read the full campaign struct.
    function getCampaign(bytes32 id) external view returns (Campaign memory) {
        return campaigns[id];
    }

    /// @notice True if `holder` has been paid for `id`.
    function isPaid(bytes32 id, address holder) external view returns (bool) {
        return paid[id][holder] != 0;
    }
}
```

### `contracts/MockUSDC.sol`

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title MockUSDC
 * @notice 6-decimal mock stablecoin with permissionless mint, suitable for testnet demos only.
 * @dev Permissionless `mint` is intentional — anyone can fund any wallet for the demo.
 *      Do NOT use this contract in any production setting.
 */
contract MockUSDC {
    string public constant name = "Mock USDC";
    string public constant symbol = "mUSDC";
    uint8  public constant decimals = 6;

    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    error InsufficientBalance();
    error InsufficientAllowance();

    /// @notice Permissionless mint — anyone can mint to anyone. Demo only.
    function mint(address to, uint256 value) external {
        balanceOf[to] += value;
        totalSupply += value;
        emit Transfer(address(0), to, value);
    }

    function transfer(address to, uint256 value) external returns (bool) {
        _transfer(msg.sender, to, value);
        return true;
    }

    function approve(address spender, uint256 value) external returns (bool) {
        allowance[msg.sender][spender] = value;
        emit Approval(msg.sender, spender, value);
        return true;
    }

    function transferFrom(address from, address to, uint256 value) external returns (bool) {
        uint256 a = allowance[from][msg.sender];
        if (a < value) revert InsufficientAllowance();
        if (a != type(uint256).max) {
            allowance[from][msg.sender] = a - value;
        }
        _transfer(from, to, value);
        return true;
    }

    function _transfer(address from, address to, uint256 value) internal {
        uint256 b = balanceOf[from];
        if (b < value) revert InsufficientBalance();
        unchecked { balanceOf[from] = b - value; }
        balanceOf[to] += value;
        emit Transfer(from, to, value);
    }
}
```

### `contracts/ShareToken.sol`

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title ShareToken
 * @notice Minimal ERC-20 representing tokenized equity shares.
 *         Pre-mints to a list of holders in the constructor.
 *
 * @dev Demo-grade: no permits, no transfer hooks, no ERC-2612.
 */
contract ShareToken {
    string public constant name = "Example Issuer Shares";
    string public constant symbol = "EIS";
    uint8  public constant decimals = 18;

    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    error LengthMismatch();
    error InsufficientBalance();
    error InsufficientAllowance();

    constructor(address[] memory holders, uint256[] memory amounts) {
        if (holders.length != amounts.length) revert LengthMismatch();
        uint256 supply;
        for (uint256 i = 0; i < holders.length; i++) {
            balanceOf[holders[i]] += amounts[i];
            supply += amounts[i];
            emit Transfer(address(0), holders[i], amounts[i]);
        }
        totalSupply = supply;
    }

    function transfer(address to, uint256 value) external returns (bool) {
        _transfer(msg.sender, to, value);
        return true;
    }

    function approve(address spender, uint256 value) external returns (bool) {
        allowance[msg.sender][spender] = value;
        emit Approval(msg.sender, spender, value);
        return true;
    }

    function transferFrom(address from, address to, uint256 value) external returns (bool) {
        uint256 a = allowance[from][msg.sender];
        if (a < value) revert InsufficientAllowance();
        if (a != type(uint256).max) {
            allowance[from][msg.sender] = a - value;
        }
        _transfer(from, to, value);
        return true;
    }

    function _transfer(address from, address to, uint256 value) internal {
        uint256 b = balanceOf[from];
        if (b < value) revert InsufficientBalance();
        unchecked { balanceOf[from] = b - value; }
        balanceOf[to] += value;
        emit Transfer(from, to, value);
    }
}
```

## Step 0b — Scaffold the example

Pull just the corporate-actions example into a fresh directory (no git history):

```bash
npx -y degit goldsky-io/documentation-examples/compose/corporate-actions#6abe62878cb92f2569538ba9572b049ed5949a01 dividend-distribution
cd dividend-distribution
```

If `npx degit` is unavailable, fall back to a sparse clone:

```bash
git clone --filter=blob:none --sparse https://github.com/goldsky-io/documentation-examples.git
cd documentation-examples && git checkout 6abe62878cb92f2569538ba9572b049ed5949a01 && git sparse-checkout set compose/corporate-actions && cd compose/corporate-actions
```

If the user already cloned the example, skip this and `cd` into it.

**Before any wallet or contract step, ask the app name — the FIRST interview question:** *"What should the app be called? (suggest `corporate-actions`)"*. The name is hard to change later: it scopes named wallets (e.g. `corp-actions-operator`) and participates in the CREATE2 salt for every `deployContract` (Step 1 Branch B reads the app name straight from `compose.yaml`), so it must be settled now. Accept the default `corporate-actions` on a shrug. The degit scaffold ships `name: "corporate-actions"` in `compose.yaml` — overwrite that `name:` with the user's chosen name before moving on.

## Preflight

The `goldsky` CLI and auth checks are the standard Compose preflight — see `/compose` and `/auth-setup`. Dividend-specific:

1. **Compose CLI version** — run `goldsky compose --version` (it prints `goldsky compose 0.8.1`). If the version is older than `0.8.1`, or if `goldsky compose deployContract` / `writeContract` are unknown commands, OFFER `goldsky compose update` and re-check before continuing. The deploy (Step 1 Branch B) and mint (Step 4) steps below depend on these commands.
2. **Project API key** — one key does the whole job (see Non-negotiables): the `-t` deploy/writeContract token, the `GOLDSKY_PROJECT_KEY` secret, and the Step 5 `$GOLDSKY_TOKEN` bearer. Generate it in the dashboard (https://app.goldsky.com) under **Settings > API Keys**. Ask the user to have it ready; do not print it back.
3. **`node` + `npm`** — `npm --version`, then `npm install` (the app bundles `viem`).
4. **`foundry`** — `cast --version` / `forge --version`. Needed only for the Step 6 `cast call` verification; **not required to deploy or mint** (`deployContract` compiles in-CLI; Step 4's mint is a gas-sponsored `writeContract`).

## Step 1 — Contracts

**Branch A — Reuse the shared demo contracts (recommended).** Nothing to deploy. Leave `CONFIG` in `src/lib/constants.ts` at the shared Base Sepolia addresses shown above. Skip to Step 2.

**Branch B — Deploy your own.** Run these from the app directory (they read `compose.yaml` for the app name). All three deploys go through the gas-sponsored Compose wallet on Base Sepolia — no funded EOA needed — and each carries `-t "$GOLDSKY_PROJECT_KEY"` for auth (an unauthenticated run fails with "run goldsky login or pass --token"). Per the confirmation rule, you may OFFER all three as a single approval ("deploy all three?") instead of three round-trips. MockUSDC and DistributionCampaign take no constructor args; ShareToken takes `(address[] holders, uint256[] amounts)`, built from `scripts/seed-holders.json`:

```bash
goldsky compose deployContract contracts/MockUSDC.sol --chain-id 84532 -t "$GOLDSKY_PROJECT_KEY"
# → capture the printed address as $PAY_TOKEN

# Build the two array tokens from scripts/seed-holders.json.
# Lowercase the holder addresses: the shipped seed-holders.json uses mixed-case
# (EIP-55) addresses that viem rejects on checksum, so ascii_downcase bypasses
# checksum validation (same resolved value forge accepts). Amounts are left as-is.
HOLDERS="$(jq -r '"[" + ([.holders[].address | ascii_downcase] | join(",")) + "]"' scripts/seed-holders.json)"
AMOUNTS="$(jq -r '"[" + ([.holders[].amount] | join(",")) + "]"' scripts/seed-holders.json)"
goldsky compose deployContract contracts/ShareToken.sol \
  --chain-id 84532 --constructor-args "$HOLDERS" "$AMOUNTS" -t "$GOLDSKY_PROJECT_KEY"
# → capture the printed address as $SHARE_TOKEN, and the printed Deploy Block as shareTokenDeployBlock

goldsky compose deployContract contracts/DistributionCampaign.sol --chain-id 84532 -t "$GOLDSKY_PROJECT_KEY"
# → capture the printed address as $CAMPAIGN_CONTRACT
```

Copy the three addresses plus `shareTokenDeployBlock` (the ShareToken Deploy Block captured above) into `CONFIG` in `src/lib/constants.ts` (`payToken`, `shareToken`, `campaignContract`, `shareTokenDeployBlock`). To run on Base mainnet instead, pass `--chain-id 8453` and set `chain`/`turboChain` to `base`. (`scripts/deploy.sh` still exists as the forge/EOA alternative if you prefer to deploy that way.) `deployContract` prints `Run 'compose codegen' to generate typed contract classes.` — safe to SKIP here; this app uses raw `wallet.writeContract` / `readContract` with signature strings and never imports generated contract classes.

## Step 2 — Set the project-key secret

The running app uses this to spawn / poll / delete Turbo pipelines:

```bash
# export GOLDSKY_PROJECT_KEY once in your shell (or source it from a chmod-600 .env);
# never paste the literal key into a command or the transcript
goldsky compose secret set GOLDSKY_PROJECT_KEY --value "$GOLDSKY_PROJECT_KEY"
```

(The scaffolded repo's `compose.yaml` comment and README still point at the plain project-secret command — that's stale; use the Compose secret command above, or deploy fails with "The following secrets referenced in the manifest do not exist or do not belong to this app".)

## Step 3 — Deploy the Compose app

```bash
goldsky compose deploy -t "$GOLDSKY_PROJECT_KEY"
```

Compose-cloud auto-provisions a hosted Neon Postgres DB and creates a project secret named `CORPORATE_ACTIONS` pointing at it; the job-mode pipelines write snapshots into that DB. First deploy may take 1-2 minutes. Watch for `Deployed compose app: <the chosen app name>` (e.g. `corporate-actions`) and the HTTP task URL.

## Step 4 — Mint MockUSDC to the operator wallet

The `declare_campaign` task itself does the USDC `approve` + `declare` on-chain via the gas-sponsored Compose wallet named **`corp-actions-operator`** (`sponsorGas: true`) — so that Compose wallet must **hold** the USDC. The `approve` happens inside the task at declare time; you don't do it manually. You only mint USDC to the wallet, and the mint is gas-sponsored too — no funded EOA, no faucet.

**(a) Get the operator wallet address.** The app is deployed by Step 3, so its wallets are listable. If `corp-actions-operator` already exists, `wallet list` shows its address; if not, `wallet create` creates it (cloud — the app must already be deployed) and prints the address. The task signs through this named wallet, so it **must** exist before Step 5:

```bash
goldsky compose wallet list -t "$GOLDSKY_PROJECT_KEY"
# If corp-actions-operator isn't listed:
goldsky compose wallet create corp-actions-operator -t "$GOLDSKY_PROJECT_KEY"
```

Capture the `corp-actions-operator` address as `$COMPOSE_WALLET`.

**(b) Mint USDC to it (sponsored).** `MockUSDC.mint` is open, so the `writeContract` sender doesn't matter; gas is sponsored. Mint generously — 1,000,000 mUSDC = `1000000000000` (6 decimals) covers many campaigns:

```bash
goldsky compose writeContract --chain-id 84532 --to $PAY_TOKEN \
  --function "mint(address,uint256)" --args $COMPOSE_WALLET 1000000000000 \
  -t "$GOLDSKY_PROJECT_KEY"
```

`$PAY_TOKEN` is `CONFIG.payToken` from `src/lib/constants.ts` — on the shared demo that's `0x8ec24F07F08745fc3D979336AA81d4Dc73f3D9DE`. On the deploy-your-own path, use your own MockUSDC address as `$PAY_TOKEN`.

## Step 5 — Declare a campaign

Pick a record block past finality, then POST. `$GOLDSKY_TOKEN` is the bearer for the HTTP task — the **same project API key** used everywhere else here (or a separate Compose API token minted from the same project; both come from **Settings > API Keys**):

```bash
RECORD_BLOCK=$(cast block-number --rpc-url https://sepolia.base.org)
RECORD_BLOCK=$((RECORD_BLOCK - 32))

curl -sX POST "https://api.goldsky.com/api/admin/compose/v1/<app name>/tasks/declare_campaign" \
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

`$ON_CHAIN_ID` comes from the Step 5 POST response body's `onChainId` field — the contract computes it as `onChainId = keccak256(encodePacked(operatorWallet, campaignId))` (the task sets `userId = campaignId`). `getCampaign(bytes32)` returns the whole `Campaign` struct, so name the full 8-field tuple return signature to make the fields decode (there's no individual getter for `escrowRemaining`):

```bash
cast call 0xA8e58573B1e10908b63d12B603aCF9C784BF904E \
  "getCampaign(bytes32)(address,address,address,uint256,uint256,uint256,bool,bool)" \
  $ON_CHAIN_ID --rpc-url https://sepolia.base.org
```

Returned fields, in order: `operator, payToken, shareToken, totalAmount, escrowRemaining, recordBlock, declared, sealed_`. `escrowRemaining` (the **5th** value) is exactly `0` once all 25 holders are paid. The full audit trail is the contract's `HolderPaid` events.

## Set your secret (final step)

The app is deployed but won't run until the `GOLDSKY_PROJECT_KEY` secret is set AND the app is (re)deployed with it. The running app uses it to spawn, poll, and delete the job-mode Turbo pipelines (see `src/lib/turbo.ts`).

- **In-app (chatbot):** the in-app deploy skips secret validation, so `deployComposeApp` succeeds without the secret. After deploy, add `GOLDSKY_PROJECT_KEY` in the Compose app's dashboard under the app's **Secrets** page, then **redeploy from the dashboard** so the pod picks it up. The app does not start working on set alone; secrets are baked into the pod at deploy, not hot-reloaded, so the redeploy is required. NEVER attempt to set a secret from chat; there is no tool, by design.
- **CLI:** you set this in Step 2 (it must exist before the CLI deploy, which validates and bakes it in). If you skipped it: `goldsky compose secret set GOLDSKY_PROJECT_KEY --value "$GOLDSKY_PROJECT_KEY"` (exported in your shell, never pasted literally), then redeploy so the pod picks it up.

## Troubleshooting

- **Edits to `compose.yaml` or source files don't take effect after redeploy.** The local `.compose/` bundle cache is stale. Run `rm -rf .compose/` and redeploy.
- **`error: Unknown command "deployContract". Did you mean command "deploy"?` (or the `writeContract` variant).** The Compose CLI is too old. Run `goldsky compose update`, confirm `goldsky compose --version` prints `0.8.1` or newer, then retry (see Preflight step 1).
- **App errors spawning the pipeline / `401` or `403` from the pipelines API.** The `GOLDSKY_PROJECT_KEY` secret is missing or wrong. Re-create it (Step 2) with a valid project API key and redeploy.
- **Snapshot never completes / campaign stuck in `snapshotting`.** Confirm `recordBlock <= currentBlock` and `>= shareTokenDeployBlock`, and that `CONFIG.shareToken` / `shareTokenDeployBlock` match the token you're distributing over. The pipeline filters `block_number BETWEEN <deployBlock> AND <recordBlock>`.
- **`declare()` reverts.** Ensure the `corp-actions-operator` Compose wallet holds enough MockUSDC for `totalAmount` (the task does the `approve` itself at declare time; mint more to the wallet in Step 4). `payToken` is **not** a contract-level setting — it's a per-`declare()` argument sourced from `CONFIG.payToken` in `src/lib/constants.ts`. If the token is wrong, edit `CONFIG.payToken` there to match the token you minted/hold, then redeploy.
- **`deployContract` refuses: "This contract has already been deployed with this app..."** An identical contract + constructor args + app name yields the same CREATE2 address, so the CLI refuses *before* the transaction and prints **no** `Deploy Block`. Levers: change a constructor arg, change the source, or use a different app name. For the two no-arg contracts here (MockUSDC, DistributionCampaign) the constructor-arg/source levers don't apply — a **different app name is the only lever**. ShareToken takes `(address[],uint256[])`, so for it the constructor-arg lever applies. ⚠ Renaming the app changes every future deploy address and conflicts with the `compose deploy` app name (the chosen app name, e.g. `corporate-actions`), so prefer the constructor-arg lever wherever it applies.
- **Campaign returns `paying` (not `complete`).** Some `pay()` calls didn't land this drive. Re-POST the same `campaignId` — already-paid holders are skipped via on-chain `isPaid()`, and the run resumes.
- **No hosted DB / snapshot rows.** Confirm the deploy created the `CORPORATE_ACTIONS` secret (compose-cloud does this automatically); if not, redeploy with `-t "$GOLDSKY_PROJECT_KEY"`.

## What you should NOT do

- Do not use the shared Base Sepolia contracts as a production target — they're permissionless (anyone can mint mUSDC or declare a campaign).
- Do not deploy this to a local/dev Compose cluster that lacks Turbo pipeline infra — the snapshot step will hang. Deploy against real Goldsky.
- Do not put the `GOLDSKY_PROJECT_KEY` on a command line where it lands in shell history beyond the `compose secret set` call; do not commit it.
- Do not lower the `recordBlock` below `shareTokenDeployBlock`, and do not use a future block — the snapshot is backwards-looking by definition.
- Do not hand-edit the per-campaign pipeline/table names in `src/lib/constants.ts` (`pipelineName` / `aggTableName`) — they're derived from `campaignId` and must stay stable for resume to work.

## Related

- **`/compose`** — Build a new/custom Compose app from scratch, or explain what Compose is.
- **`/compose-reference`** — Manifest, CLI, TaskContext API, wallets, gas sponsorship, codegen.
- **`/compose-doctor`** — Diagnose and fix a broken Compose app.
- **`/turbo-pipelines`** / **`/turbo-operations`** — Job-mode pipeline shape and lifecycle, if customizing the snapshot.
- **`/auth-setup`** — `goldsky login` walkthrough.
