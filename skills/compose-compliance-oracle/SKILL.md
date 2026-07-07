---
name: compose-compliance-oracle
description: "Build and deploy the Goldsky Compose compliance-oracle example under the user's own account — a compliance-gated payment gateway where a smart contract holds a USDC payment in escrow, Compose screens the sender wallet via the Webacy AML API on the emitted TransferRequested event, then calls back to approve (funds to the business wallet) or reject (funds returned to sender). Ships a second cron task that reconciles stuck transfers. Triggers on: 'build a compliance oracle', 'compliance-gated payments', 'AML screening onchain', 'KYC payment gateway', 'escrow with compliance check', 'wallet screening oracle', 'gated transfers', 'Webacy oracle'. The escrow contract's approve/reject are oracle-permissioned, so there is no shared no-deploy contract — each user deploys their own instance bound to their oracle wallet (recommended path: Base Sepolia + a MockUSDC). The oracle signs via a private-key secret with sponsored gas. For a custom/novel Compose app, use /compose. For debugging a deployed app, use /compose-doctor. For manifest/CLI/API field lookups, use /compose-reference."
---

# Build: Compose compliance-oracle

Stand up the compliance payment gateway under the user's own Goldsky account. A `ComplianceGatedTransfer` contract accepts a USDC payment from any sender and holds it in escrow, emitting `TransferRequested`. Compose reacts to that event, screens the sender wallet via the **Webacy** AML API, then signs a callback: `approveTransfer` (escrowed funds go to the oracle/business wallet) or `rejectTransfer` (funds returned to the sender). Every decision is written to a durable `transfer-audits` collection, and a `reconcile` cron catches transfers left stuck in `Pending`. Gas is sponsored — the oracle wallet never needs native token.

This template supplies only what's specific to the compliance app — how it works and its **full source** (below). Unlike the VRF or bitcoin-oracle examples, **there is no shared no-deploy contract**: `approveTransfer`/`rejectTransfer` are `onlyOracle`-gated (that's the security model — only the oracle may release escrow), so each instance is bound at construction to one oracle address. Every user deploys their own contract with their own oracle wallet as `oracle`. The recommended path is **Base Sepolia** with a `MockUSDC` you deploy, so it's free and fully gas-sponsored; graduate to Base mainnet with native USDC for production.

## Step 0 — Load the base skills first

**Before anything else — before you answer, ask a question, scaffold a file, or run any command — load the two base skills this template depends on:**

1. **`Skill(compose)`** — the always-on Compose guide: the golden rules (never assume anything about the app on the user's behalf; ask when unsure) and general build guidance.
2. **`Skill(compose-reference)`** — the manifest / field / API reference; consult before writing any `compose.yaml` or task file.

This template deliberately omits those rules and that reference — they are **required** to build correctly and are not repeated here. Do not proceed until both are loaded.

## Mode Detection

Pick the mode from the tools available to you:

- **A `deployComposeApp` tool is available (Goldsky webapp chatbot).** This example **cannot be fully stood up through the in-app deploy card**, and that is expected — say so plainly. Two hard reasons: (1) it requires an `ORACLE_PRIVATE_KEY` secret (and a `WEBACY_API_KEY`) that only the `goldsky` CLI / dashboard can set, and (2) the Compose app is useless until an oracle-bound `ComplianceGatedTransfer` contract is deployed on-chain — and that contract must be constructed with the oracle wallet's address, which means deploying it first with `forge`. The in-app card does neither. So do NOT scaffold files or call `deployComposeApp`. Instead: give a 3-4 sentence explanation of what the app does and why it's CLI-driven, then walk the user through the CLI steps below (or tell them to run this skill locally with `npx skills add goldsky-io/goldsky-agent` where a `Bash` tool is available). Everything from **The app (full source)** down is that CLI procedure.
- **`Bash` is available (local CLI / coding agent):** execute the steps below directly, parse output, and substitute captured values into later commands.
- **Neither (pure reference Q&A):** explain what the app does and the escrow → screen → approve/reject lifecycle; only if asked for step-by-step help, output one command at a time and have the user paste output back. Point them at `npx skills add goldsky-io/goldsky-agent` to run it locally with Bash.

## Variable handling for agents

When this skill says `$FOO`, capture the literal value from the prior command's output and substitute it directly into the next command. Do not rely on shell variables persisting between separate Bash tool invocations — each invocation gets a fresh shell.

## Non-negotiables

- **There is no shared, reusable contract.** `approveTransfer`, `rejectTransfer`, and `setOracle` are all `onlyOracle` (`require(msg.sender == oracle)`), and `oracle` is fixed at construction. A user cannot point their app at someone else's deployed instance — only that instance's oracle key can sign valid callbacks. Every user deploys their own via Step 2. (An older demo instance exists on Base **mainnet** at `0x39efE8A851A4Da22fa40828F6D4b3DC6b54545Aa`, but its oracle is a fixed key nobody else holds, so it is reference-only, not reusable.)
- **The oracle wallet address must equal the contract's `oracle`.** The contract is deployed with `--constructor-args <USDC> <ORACLE_ADDRESS>`, where `ORACLE_ADDRESS = cast wallet address $ORACLE_PRIVATE_KEY`. The Compose task loads that same key via `evm.wallet({ privateKey: env.ORACLE_PRIVATE_KEY })`. If they don't match, every `approveTransfer`/`rejectTransfer` reverts with `not oracle`.
- **Gas sponsorship:** the oracle wallet uses `sponsorGas: true` — it never needs native token for gas on sponsored chains (Base, Base Sepolia). The `ORACLE_PRIVATE_KEY` EOA only needs gas to *deploy the contract* with `forge`, never at task runtime.
- **`ORACLE_PRIVATE_KEY` is a real EOA private key.** Never print it, commit it, or log it. It is set once as a Compose secret and passed to `deploy.sh` as an env var — nowhere else.
- **Do not import external packages in task code.** `evm`, `fetch`, `collection`, `env`, and `logger` all come from the injected `context` argument. The only import allowed in tasks is `compose` (for types) and sibling project files.
- **Never run `forge create`, `goldsky compose deploy`, `goldsky compose secret set`, `git push`, or `gh repo create` without showing the exact command first and getting explicit confirmation.**

## The app (full source)

This is the complete compliance app. Scaffold these files verbatim (Step 0 writes them to disk; the in-app flow scaffolds them in-memory) — there is nothing to clone. Only edit `compose.yaml` and `src/lib/constants.ts` to wire in your deployed contract address and chain (Step 3). The source below is pointed at Base **mainnet** with native USDC — the recommended getting-started path swaps that to Base Sepolia + a MockUSDC in Step 3.

### `compose.yaml`

```yaml
name: "compliance-oracle"
api_version: "internal-pk-sponsored-otel"

secrets:
  - ORACLE_PRIVATE_KEY
  - WEBACY_API_KEY

tasks:
  - name: "on_transfer_requested"
    path: "./src/tasks/on-transfer-requested.ts"
    retry_config:
      max_attempts: 3
      initial_interval_ms: 1000
      backoff_factor: 2
    triggers:
      - type: onchain_event
        network: "base"
        contract: "0x39efE8A851A4Da22fa40828F6D4b3DC6b54545Aa"
        events:
          - "TransferRequested(uint256,address,uint256)"

  - name: "reconcile"
    path: "./src/tasks/reconcile.ts"
    triggers:
      - type: cron
        expression: "*/5 * * * *"
```

### `tsconfig.json`

```json
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "ES2022",
    "moduleResolution": "bundler",
    "strict": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "outDir": "./dist",
    "baseUrl": ".",
    "paths": {
      "compose": [".compose/types.d.ts"]
    }
  },
  "include": ["src/**/*.ts"]
}
```

### `contracts/ComplianceGatedTransfer.sol`

Single-payee escrow: on approval, funds go to the `oracle` (business) wallet; on rejection, back to the sender. Imports OpenZeppelin's `IERC20` (installed in Preflight).

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract ComplianceGatedTransfer {
    enum Status { Pending, Approved, Rejected }

    struct Transfer {
        address sender;
        uint256 amount;
        Status status;
    }

    IERC20 public immutable usdc;
    address public oracle;
    uint256 public nextTransferId;

    mapping(uint256 => Transfer) public transfers;

    event TransferRequested(
        uint256 indexed id,
        address indexed sender,
        uint256 amount
    );
    event TransferApproved(uint256 indexed id);
    event TransferRejected(uint256 indexed id);
    event OracleUpdated(address indexed oldOracle, address indexed newOracle);

    modifier onlyOracle() {
        require(msg.sender == oracle, "not oracle");
        _;
    }

    constructor(address _usdc, address _oracle) {
        usdc = IERC20(_usdc);
        oracle = _oracle;
    }

    /// @notice User calls this to send a compliance-screened payment.
    ///         User must have approved this contract to spend `amount` of USDC first.
    ///         If approved, funds go to the oracle (business) wallet.
    function requestTransfer(uint256 amount) external {
        require(amount > 0, "zero amount");

        usdc.transferFrom(msg.sender, address(this), amount);

        uint256 id = nextTransferId++;
        transfers[id] = Transfer({
            sender: msg.sender,
            amount: amount,
            status: Status.Pending
        });

        emit TransferRequested(id, msg.sender, amount);
    }

    /// @notice Oracle approves the transfer — funds go to the oracle (business) wallet.
    function approveTransfer(uint256 id) external onlyOracle {
        Transfer storage t = transfers[id];
        require(t.status == Status.Pending, "not pending");
        t.status = Status.Approved;
        usdc.transfer(oracle, t.amount);
        emit TransferApproved(id);
    }

    /// @notice Oracle rejects the transfer — funds returned to sender.
    function rejectTransfer(uint256 id) external onlyOracle {
        Transfer storage t = transfers[id];
        require(t.status == Status.Pending, "not pending");
        t.status = Status.Rejected;
        usdc.transfer(t.sender, t.amount);
        emit TransferRejected(id);
    }

    /// @notice Allow oracle address to be updated (for key rotation).
    function setOracle(address _oracle) external onlyOracle {
        emit OracleUpdated(oracle, _oracle);
        oracle = _oracle;
    }
}
```

### `contracts/MockUSDC.sol` (Base Sepolia / recommended path only)

Native USDC only exists on mainnet. On Base Sepolia, deploy this mintable 6-decimal ERC-20 first and use its address as the escrow's `_usdc` constructor arg. Open `mint` so you can fund sender wallets freely on testnet.

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockUSDC is ERC20 {
    constructor() ERC20("Mock USDC", "USDC") {}

    function decimals() public pure override returns (uint8) {
        return 6;
    }

    /// @notice Open mint — testnet only.
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}
```

### `src/lib/constants.ts`

```typescript
import type { Hex } from "compose";

export const CONFIG = {
  chain: "base" as const,

  // Deployed ComplianceGatedTransfer contract address — update after deployment
  contractAddress: "0x39efE8A851A4Da22fa40828F6D4b3DC6b54545Aa" as Hex,

  // Native USDC on Base
  // https://basescan.org/token/0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913
  usdcAddress: "0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913" as Hex,

  usdcDecimals: 6,

};

// Webacy risk score threshold (0-100 scale)
// Transfers from wallets scoring above this are rejected
export const RISK_THRESHOLD = 50;
```

### `src/lib/webacy.ts`

The screening client. GETs Webacy's address risk report and returns a normalized result; the task rejects any sender whose `overallRisk` is at or above `RISK_THRESHOLD`.

```typescript
import { TaskContext } from "compose";

export type WalletScreeningResult = {
  address: string;
  riskScore: number | null;
  passed: boolean;
  triggeredRules: string[];
};

type WebacyIssueTag = {
  name: string;
  description: string;
  severity: number;
  key: string;
};

type WebacyIssue = {
  score: number;
  tags: WebacyIssueTag[];
};

type WebacyResponse = {
  count: number;
  medium: number;
  high: number;
  overallRisk: number;
  addressType: string;
  issues: WebacyIssue[];
};

const WEBACY_API_BASE = "https://api.webacy.com";

export async function screenWallet(
  address: string,
  apiKey: string,
  riskThreshold: number,
  fetchFn: TaskContext["fetch"],
): Promise<WalletScreeningResult> {
  const url = `${WEBACY_API_BASE}/addresses/${address}?chain=base`;

  const data = await fetchFn<WebacyResponse>(url, {
    method: "GET",
    headers: {
      "x-api-key": apiKey,
    },
  });

  if (!data) {
    throw new Error(`Webacy API returned empty response for ${address}`);
  }

  const riskScore = data.overallRisk ?? null;

  const triggeredRules: string[] = (data.issues ?? [])
    .flatMap((issue) => issue.tags ?? [])
    .filter((tag) => tag.severity >= 2)
    .map((tag) => tag.name);

  return {
    address,
    riskScore,
    passed: riskScore === null || riskScore < riskThreshold,
    triggeredRules,
  };
}
```

### `src/tasks/on-transfer-requested.ts`

The main task. Decodes the event, screens the sender, signs `approveTransfer`/`rejectTransfer` via the private-key oracle wallet (gas-sponsored), and writes an audit record.

```typescript
import { TaskContext, OnchainEvent } from "compose";
import { CONFIG, RISK_THRESHOLD } from "../lib/constants";
import { screenWallet, WalletScreeningResult } from "../lib/webacy";

type TransferAuditRecord = {
  transferId: string;
  sender: string;
  amount: string;
  screening: WalletScreeningResult;
  decision: "approved" | "rejected";
  reason: string;
  depositTxHash: string;
  oracleTxHash: string;
  timestamp: string;
};

type TransferRequestedEvent = {
  eventName: "TransferRequested";
  args: { id: bigint; sender: string; amount: bigint };
};

function formatUsdc(raw: bigint): string {
  return `${(Number(raw) / 1e6).toFixed(2)} USDC`;
}

export async function main(ctx: TaskContext, payload: OnchainEvent) {
  const { evm, collection, env, fetch: ctxFetch } = ctx;
  const log = ctx.logger;

  // --- Step 1: Decode the onchain event ---

  const decoded = await evm.decodeEventLog<TransferRequestedEvent>(
    [{
      type: "event",
      name: "TransferRequested",
      inputs: [
        { name: "id", type: "uint256", indexed: true },
        { name: "sender", type: "address", indexed: true },
        { name: "amount", type: "uint256", indexed: false },
      ],
    }],
    payload,
  );

  const { id, sender, amount } = decoded.args;
  const transferId = id.toString();
  const depositTxHash = (payload as any).transaction_hash;

  log.info(`deposit received: ${formatUsdc(amount)}, from ${sender}`);

  // --- Step 2: Screen the depositor via Webacy ---

  log.info(`screening depositor ${sender}`);

  const screenResult = await screenWallet(sender, env.WEBACY_API_KEY, RISK_THRESHOLD, ctxFetch);

  log.info(`screening complete for ${sender}, risk score: ${screenResult.riskScore}`);

  // --- Step 3: Call back to the escrow contract ---

  const wallet = await evm.wallet({ privateKey: env.ORACLE_PRIVATE_KEY, sponsorGas: true });

  let txHash: string;
  let decision: "approved" | "rejected";
  let reason: string;

  if (screenResult.passed) {
    decision = "approved";
    reason = `Sender score: ${screenResult.riskScore}. Below threshold ${RISK_THRESHOLD}.`;

    log.info(`approving transfer #${transferId} — ${formatUsdc(amount)} to vault wallet`);

    const result = await wallet.writeContract(
      evm.chains[CONFIG.chain],
      CONFIG.contractAddress,
      "approveTransfer(uint256)",
      [id],
    );
    txHash = result.hash;

    log.info(`transfer #${transferId} APPROVED`, {
      oracleTxHash: txHash,
      amount: formatUsdc(amount),
      sender,
    });
  } else {
    decision = "rejected";
    reason = `Sender flagged (score: ${screenResult.riskScore}, rules: ${screenResult.triggeredRules.join(", ")})`;

    log.warn(`rejecting transfer #${transferId} — returning ${formatUsdc(amount)} to ${sender}`);

    const result = await wallet.writeContract(
      evm.chains[CONFIG.chain],
      CONFIG.contractAddress,
      "rejectTransfer(uint256)",
      [id],
    );
    txHash = result.hash;
  }

  // --- Step 4: Persist audit record ---

  const audits = await collection<TransferAuditRecord>("transfer-audits");

  await audits.setById(transferId, {
    transferId,
    sender,
    amount: amount.toString(),
    screening: screenResult,
    decision,
    reason,
    depositTxHash,
    oracleTxHash: txHash,
    timestamp: new Date().toISOString(),
  });

  log.info(`audit record saved for transfer #${transferId}`);

  return { transferId, decision, reason, depositTxHash, oracleTxHash: txHash };
}
```

### `src/tasks/reconcile.ts`

A safety-net cron (every 5 minutes). Scans the contract for transfers stuck in `Pending` — an event the main task missed or a failed callback — and logs an alert so nothing sits in escrow silently.

```typescript
import { TaskContext } from "compose";
import { CONFIG } from "../lib/constants";

export async function main(ctx: TaskContext) {
  const { evm } = ctx;

  // Use the oracle private key for read calls (address must match the contract's oracle)
  const wallet = await evm.wallet({ privateKey: ctx.env.ORACLE_PRIVATE_KEY });

  // Read how many transfers exist on the contract
  const totalTransfers = await wallet.readContract<bigint>(
    evm.chains[CONFIG.chain],
    CONFIG.contractAddress,
    "nextTransferId() returns (uint256)",
    [],
  );

  // Check each transfer's status onchain
  // In production you'd track a cursor; for the demo, scan all
  let pendingCount = 0;
  const staleTransfers: number[] = [];

  for (let i = 0; i < Number(totalTransfers); i++) {
    const transfer = await wallet.readContract<[string, bigint, number]>(
      evm.chains[CONFIG.chain],
      CONFIG.contractAddress,
      "transfers(uint256) returns (address,uint256,uint8)",
      [i],
    );

    const status = transfer[2]; // 0 = Pending, 1 = Approved, 2 = Rejected
    if (status === 0) {
      pendingCount++;
      staleTransfers.push(i);
    }
  }

  const report = {
    timestamp: new Date().toISOString(),
    totalTransfers: Number(totalTransfers),
    pendingCount,
    staleTransferIds: staleTransfers,
    healthy: pendingCount === 0,
  };

  if (pendingCount > 0) {
    ctx.logger.error("stale pending transfers detected", report);
  } else {
    ctx.logger.info("reconciliation passed", report);
  }

  return report;
}
```

### `foundry.toml`

```toml
[profile.default]
src = "contracts"
out = "out"
libs = ["lib"]
```

---

> **The steps below are the Bash / local-CLI procedure. If a `deployComposeApp` tool is available (webapp chatbot), do NOT follow them — this example is CLI-driven; see Mode Detection above.**

## Step 0 — Scaffold the project

Create the directory layout and write each file from **The app (full source)** above — there is nothing to clone.

```bash
mkdir -p compliance-oracle/src/tasks compliance-oracle/src/lib compliance-oracle/contracts
cd compliance-oracle
```

Write these files verbatim from the source above: `compose.yaml`, `tsconfig.json`, `foundry.toml`, `contracts/ComplianceGatedTransfer.sol`, `contracts/MockUSDC.sol`, `src/lib/constants.ts`, `src/lib/webacy.ts`, `src/tasks/on-transfer-requested.ts`, and `src/tasks/reconcile.ts`. Then wire the deployed address and chain in Step 3. Add a `.gitignore` containing `.env`, `lib/`, and `.compose/`.

## Preflight

The `goldsky` CLI and auth checks are the standard Compose preflight — see `/compose` and `/auth-setup`. Compliance-specific:

1. **`forge` + `cast`** — `forge --version`. Install with `curl -L https://foundry.paradigm.xyz | bash && foundryup` if missing. Required to deploy the contract.
2. **OpenZeppelin contracts** — the escrow contract imports `IERC20` (and MockUSDC imports `ERC20`). From the project root: `forge install OpenZeppelin/openzeppelin-contracts --no-commit`.
3. **Webacy API key** — sign up at https://developers.webacy.co/ and create an API key (a demo key is available right after signup). Have it ready; do not print it back.

## Step 1 — Configuration interview

Name the app `compliance-oracle` (don't ask). Then, per the golden rules in `/compose`, ask only what you can't derive, one question at a time:

1. **"Which chain?"** — **Base Sepolia (recommended)** — free, gas-sponsored, and you mint your own test USDC. Base mainnet is production (real USDC, real screening, real funds). Use the camelCase form in TS (`baseSepolia`) and snake_case in `compose.yaml` (`base_sepolia`).
2. **"What risk threshold?"** — Webacy `overallRisk` is 0-100; senders scoring at or above the threshold are rejected. Default `50`. Set `RISK_THRESHOLD` in `src/lib/constants.ts`.
3. **Recipient** — approved funds go to the **oracle (business) wallet** itself (the contract sends escrow to `oracle` on approval). That's the deployer of the contract. No separate recipient to configure.

## Step 2 — Oracle wallet and contract deploy

The oracle wallet is a plain EOA private key. Its address becomes the contract's `oracle`, and the same key signs the Compose callbacks. Have the user provide `ORACLE_PRIVATE_KEY` (an EOA with a little gas on the target chain to pay for the *deploy* — runtime callbacks are sponsored), or generate one:

```bash
cast wallet new
# → Address and private key. Save the private key as ORACLE_PRIVATE_KEY.
```

Create `.env` in the project root with it (never commit this file):

```env
ORACLE_PRIVATE_KEY=0x_your_oracle_private_key
RPC_URL=https://sepolia.base.org   # or https://mainnet.base.org for production
WEBACY_API_KEY=your_webacy_api_key
```

**Base Sepolia (recommended): deploy a MockUSDC first**, then use its address as the escrow's `_usdc` arg. Fund the oracle EOA from a faucet (e.g. https://www.alchemy.com/faucets/base-sepolia) if `cast balance $ORACLE_ADDRESS --rpc-url $RPC_URL` shows zero.

```bash
source .env
ORACLE_ADDRESS=$(cast wallet address "$ORACLE_PRIVATE_KEY")

# 1) MockUSDC
forge create contracts/MockUSDC.sol:MockUSDC \
  --rpc-url "$RPC_URL" --private-key "$ORACLE_PRIVATE_KEY" --broadcast
# capture "Deployed to:" as $USDC_ADDRESS

# 2) ComplianceGatedTransfer(usdc, oracle)
forge create contracts/ComplianceGatedTransfer.sol:ComplianceGatedTransfer \
  --rpc-url "$RPC_URL" --private-key "$ORACLE_PRIVATE_KEY" --broadcast \
  --constructor-args "$USDC_ADDRESS" "$ORACLE_ADDRESS"
# capture "Deployed to:" as $CONTRACT_ADDRESS
```

**Base mainnet (production):** skip MockUSDC — use native USDC `0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913` as `$USDC_ADDRESS`. The repo's `scripts/deploy-contract/deploy.sh` automates exactly this against `RPC_URL` (defaults to mainnet); it reads `ORACLE_PRIVATE_KEY` from `.env`, derives the oracle address, and deploys the escrow with native USDC.

Capture `$CONTRACT_ADDRESS` and `$USDC_ADDRESS` for the next step.

## Step 3 — Wire the contract address and chain into the app

Two files reference the chain/addresses. Use grep anchors — line numbers shift.

**`src/lib/constants.ts`:**
- `chain:` → `"baseSepolia"` (Base Sepolia) or leave `"base"` (mainnet).
- `contractAddress:` → `$CONTRACT_ADDRESS`.
- `usdcAddress:` → `$USDC_ADDRESS` (your MockUSDC on Sepolia; native USDC on mainnet).

**`compose.yaml`** (inside the `on_transfer_requested` trigger):
- `network:` → `"base_sepolia"` or `"base"` (snake_case).
- `contract:` → `$CONTRACT_ADDRESS`.

The event signature `TransferRequested(uint256,address,uint256)` stays as-is — it matches the contract. Show a diff before applying, then apply with Edit.

## Step 4 — Set Compose secrets

The running app needs the oracle key (to sign callbacks) and the Webacy key (to screen):

```bash
source .env
goldsky compose secret set ORACLE_PRIVATE_KEY --value "$ORACLE_PRIVATE_KEY"
goldsky compose secret set WEBACY_API_KEY --value "$WEBACY_API_KEY"
```

## Step 5 — Optional: publish to a new GitHub repo

```bash
git init
git add .
git ls-files --cached | grep -iE '(\.env$|private[._-]?key|\.pem|id_rsa)' && \
  { echo "ABORT: secret-shaped file staged"; exit 1; }
git commit -m "Initial commit: Compose compliance-oracle"
gh repo create <user's repo name> --<public|private> --source=. --push
```

(The `.gitignore` from Step 0 excludes `.env`; the grep is a backstop — never commit the oracle key.)

## Step 6 — Deploy to Goldsky

```bash
goldsky compose deploy
```

First deploy may take 1-2 minutes. Watch for `Deployed compose app: compliance-oracle`. The `on_transfer_requested` event listener and the `reconcile` cron both go live.

## Step 7 — Smoke test

Drive the full flow from a sender wallet with `cast`: fund it, approve the escrow to spend, then request a transfer. Use a separate sender key (`$SENDER_KEY`), not the oracle key.

On Base Sepolia, first mint test USDC to the sender so it has something to pay with (the oracle EOA can mint on the open MockUSDC):

```bash
cast send $USDC_ADDRESS "mint(address,uint256)" $SENDER_ADDRESS 1000000 \
  --rpc-url $RPC_URL --private-key $ORACLE_PRIVATE_KEY   # 1.00 mUSDC
```

Then approve and request (ERC-20 transfers need prior approval of the escrow as spender):

```bash
cast send $USDC_ADDRESS "approve(address,uint256)" $CONTRACT_ADDRESS 1000000 \
  --rpc-url $RPC_URL --private-key $SENDER_KEY
cast send $CONTRACT_ADDRESS "requestTransfer(uint256)" 1000000 \
  --rpc-url $RPC_URL --private-key $SENDER_KEY
```

Then tail logs and watch the decision land:

```bash
goldsky compose logs
```

**What to look for:** `deposit received`, `screening complete ... risk score N`, then `transfer #<id> APPROVED` (or a reject warning) with an `oracleTxHash`. Verify on-chain — `transfers(<id>)` status should be `1` (Approved) or `2` (Rejected), not `0`:

```bash
cast call $CONTRACT_ADDRESS "transfers(uint256)(address,uint256,uint8)" <id> --rpc-url $RPC_URL
```

## Troubleshooting

- **Edits to `compose.yaml` or source files don't take effect after redeploy.** Stale `.compose/` bundle cache. Run `rm -rf .compose/` and redeploy.
- **`approveTransfer`/`rejectTransfer` reverts with `not oracle`.** The Compose wallet's address doesn't match the contract's `oracle`. They must derive from the same `ORACLE_PRIVATE_KEY`. Check: `cast call $CONTRACT_ADDRESS "oracle()(address)" --rpc-url $RPC_URL` should equal `cast wallet address $ORACLE_PRIVATE_KEY`.
- **`requestTransfer` reverts with "transfer amount exceeds allowance".** The sender didn't `approve` the escrow to spend their USDC first. Run the `approve` call before `requestTransfer`.
- **Task never fires when a transfer is requested.** Confirm `compose.yaml`'s `contract:` and `network:` match where you deployed, the deploy succeeded, and the trigger is active (`goldsky compose status`). Wiring only one of `chain` (constants.ts) / `network` (compose.yaml) is the usual cause.
- **Webacy returns an empty response / task throws.** Check `WEBACY_API_KEY` is set as a secret and valid, and the address is well-formed hex. Transient failures are absorbed by the `retry_config` (3 attempts, backoff).
- **Reject scenario approves instead.** On Base Sepolia, a fresh test wallet has no on-chain history, so Webacy scores it low (it passes). Use a known-flagged address, or test the reject path on mainnet where real risk data exists.
- **`insufficient funds for gas` on deploy.** Only the *contract deploy* needs gas on the oracle EOA. Fund it from a faucet (Sepolia) or with a little ETH (mainnet). Runtime callbacks are sponsored and need nothing.

## What you should NOT do

- Do not point the app at the mainnet demo contract `0x39efE8A851A4Da22fa40828F6D4b3DC6b54545Aa` (or any contract you didn't deploy). Its `oracle` is a fixed key you don't hold, so every callback reverts `not oracle`. Deploy your own.
- Do not use a different key for the contract's `oracle` constructor arg than the one in `ORACLE_PRIVATE_KEY`. They must be the same EOA.
- Do not commit or log `ORACLE_PRIVATE_KEY`. It is a real signing key.
- Do not import `viem`, `ethers`, or any external package inside the Compose task code — use `evm.decodeEventLog`, `evm.wallet`, and `evm.chains` from the context.
- Do not deploy the gated-transfer contract to Base mainnet with real USDC as a first test — start on Base Sepolia with MockUSDC.

## Related

- **`/compose`** — Build a new/custom Compose app from scratch, or explain what Compose is.
- **`/compose-reference`** — Manifest, CLI, TaskContext API, wallets, gas sponsorship, codegen.
- **`/compose-doctor`** — Diagnose and fix a broken Compose app.
- **`/auth-setup`** — `goldsky login` walkthrough.
