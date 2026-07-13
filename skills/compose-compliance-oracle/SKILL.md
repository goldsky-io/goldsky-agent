---
name: compose-compliance-oracle
description: "Build and deploy the Goldsky Compose compliance-oracle example under the user's own account — a compliance-gated payment system where a smart contract holds funds in escrow, Compose screens the sender wallet via a compliance API (Webacy recommended, or bring-your-own / mock), then calls back to approve or reject. Supports two payment models: single-payee (payment gateway — funds go to a configurable recipient) and multi-payee (P2P — sender specifies recipient per transfer). Ships a second cron task that reconciles stuck transfers. Triggers on: 'build a compliance oracle', 'compliance-gated payments', 'AML screening onchain', 'KYC payment gateway', 'escrow with compliance check', 'wallet screening oracle', 'gated transfers', 'Webacy oracle', 'P2P compliance', 'payment gateway with screening'. The escrow contract's approve/reject are oracle-permissioned, so there is no shared no-deploy contract — each user deploys their own instance bound to their oracle wallet (recommended path: Base Sepolia + a MockUSDC). The oracle signs via a private-key secret with sponsored gas. For a custom/novel Compose app, use /compose. For debugging a deployed app, use /compose-doctor. For manifest/CLI/API field lookups, use /compose-reference."
---

# Build: Compose compliance-oracle

Stand up a compliance-gated payment system under the user's own Goldsky account. A `ComplianceGatedTransfer` contract accepts a payment from any sender and holds it in escrow, emitting `TransferRequested`. Compose reacts to that event, screens the sender wallet via a compliance API, then signs a callback: `approveTransfer` (funds go to the intended recipient) or `rejectTransfer` (funds returned to the sender). Every decision is written to a durable `transfer-audits` collection, and a `reconcile` cron catches transfers left stuck in `Pending`. Gas is sponsored — the oracle wallet never needs native token.

**Two payment models** (chosen during configuration):
- **Single-payee** (payment gateway / deposit flow) — all approved funds go to one configurable `recipient` address, set at construction and changeable via `setRecipient()`. The recipient is separate from the oracle signer.
- **Multi-payee** (P2P transfers) — the sender specifies a recipient per transfer via `requestTransfer(amount, recipient)`.

**Three compliance provider options:**
- **Webacy (recommended)** — simple REST API, one API key. Sign up at https://developers.webacy.co/ for a free demo key.
- **Mock mode** — hardcoded allow/deny list, no API key needed. Good for testing the flow before committing to a provider.
- **Bring your own** — scaffolds the `screenWallet()` interface for you to implement with any provider.

This template supplies only what's specific to the compliance app — how it works and its **full source** (below). Unlike the VRF or bitcoin-oracle examples, **there is no shared no-deploy contract**: `approveTransfer`/`rejectTransfer` are `onlyOracle`-gated (that's the security model — only the oracle may release escrow), so each instance is bound at construction to one oracle address. Every user deploys their own contract with their own oracle wallet as `oracle`. The recommended path is **Base Sepolia** with a `MockUSDC` you deploy, so it's free and fully gas-sponsored; graduate to mainnet for production. Any EVM chain Compose supports works — Base Sepolia is recommended because it's free and gas-sponsored.

## Step 0a — Load the base skills first

**Before anything else — before you answer, ask a question, scaffold a file, or run any command — load the two base skills this template depends on:**

1. **`Skill(compose)`** — the always-on Compose guide: the golden rules (never assume anything about the app on the user's behalf; ask when unsure) and general build guidance.
2. **`Skill(compose-reference)`** — the manifest / field / API reference; consult before writing any `compose.yaml` or task file.

This template deliberately omits those rules and that reference — they are **required** to build correctly and are not repeated here. Do not proceed until both are loaded.

## Mode Detection

Pick the mode from the tools available to you:

- **A `deployComposeApp` tool is available (Goldsky webapp chatbot).** This example **cannot be fully stood up through the in-app deploy card**, and that is expected — say so plainly. Two hard reasons: (1) it requires an `ORACLE_PRIVATE_KEY` secret (and a `WEBACY_API_KEY`) that only the `goldsky` CLI / dashboard can set, and (2) the Compose app is useless until an oracle-bound `ComplianceGatedTransfer` contract is deployed on-chain — and that contract must be constructed with the oracle wallet's address, which means deploying it first via `goldsky compose deployContract`. The in-app card does neither. So do NOT scaffold files or call `deployComposeApp`. Instead: give a 3-4 sentence explanation of what the app does and why it's CLI-driven, then walk the user through the CLI steps below (or tell them to run this skill locally with `npx skills add goldsky-io/goldsky-agent` where a `Bash` tool is available). Everything from **The app (full source)** down is that CLI procedure.
- **`Bash` is available (local CLI / coding agent):** execute the steps below directly, parse output, and substitute captured values into later commands.
- **Neither (pure reference Q&A):** explain what the app does and the escrow → screen → approve/reject lifecycle; only if asked for step-by-step help, output one command at a time and have the user paste output back. Point them at `npx skills add goldsky-io/goldsky-agent` to run it locally with Bash.

## Variable handling for agents

When this skill says `$FOO`, capture the literal value from the prior command's output and substitute it directly into the next command. Do not rely on shell variables persisting between separate Bash tool invocations — each invocation gets a fresh shell.

## Non-negotiables

- **There is no shared, reusable contract.** `approveTransfer`, `rejectTransfer`, and `setOracle` are all `onlyOracle` (`require(msg.sender == oracle)`), and `oracle` is fixed at construction. A user cannot point their app at someone else's deployed instance — only that instance's oracle key can sign valid callbacks. Every user deploys their own via Step 2. (An older demo instance exists on Base **mainnet** at `0x39efE8A851A4Da22fa40828F6D4b3DC6b54545Aa`, but its oracle is a fixed key nobody else holds, so it is reference-only, not reusable.)
- **The oracle wallet address must equal the contract's `oracle`.** The contract is deployed with `--constructor-args <USDC> <ORACLE_ADDRESS>`, where `ORACLE_ADDRESS = cast wallet address $ORACLE_PRIVATE_KEY`. The Compose task loads that same key via `evm.wallet({ privateKey: env.ORACLE_PRIVATE_KEY })`. If they don't match, every `approveTransfer`/`rejectTransfer` reverts with `not oracle`.
- **Gas sponsorship:** the oracle wallet uses `sponsorGas: true` — it never needs native token for gas on sponsored chains (Base, Base Sepolia). The `ORACLE_PRIVATE_KEY` EOA needs **no gas for the deploy or at runtime** — not even deployment costs the oracle key anything, since `goldsky compose deployContract` deploys through the gas-sponsored Compose wallet, not the oracle key.
- **`ORACLE_PRIVATE_KEY` is a real EOA private key.** Never print it, commit it, or log it. It is set once as a Compose secret and used locally only to derive its address (`cast wallet address $ORACLE_PRIVATE_KEY`) for the constructor arg — nowhere else.
- **Do not import external packages in task code.** `evm`, `fetch`, `collection`, `env`, and `logger` all come from the injected `context` argument. The only import allowed in tasks is `compose` (for types) and sibling project files.
- **Never run `goldsky compose deployContract`, `goldsky compose deploy`, `goldsky compose secret set`, `git push`, or `gh repo create` without showing the exact command first and getting explicit confirmation.**

## The app (full source)

This is the complete compliance app. Scaffold these files verbatim (Step 0b writes them to disk; the in-app flow scaffolds them in-memory) — there is nothing to clone. ⚠ The addresses shipped in `compose.yaml` and `src/lib/constants.ts` below (`contract:` and `contractAddress:` both default to the mainnet demo escrow `0x39efE8A851A4Da22fa40828F6D4b3DC6b54545Aa`) are **placeholders** — Step 3 wiring is **MANDATORY** before deploy; unwired, every callback reverts `not oracle`. Only edit those two files to wire in your deployed contract address and chain. The source below is pointed at Base **mainnet** with native USDC — the recommended getting-started path swaps that to Base Sepolia + a MockUSDC in Step 3.

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

> **`api_version: "internal-pk-sponsored-otel"`** pins an internal image channel that skips version-compatibility checks — required today for BYO-private-key (`ORACLE_PRIVATE_KEY`) combined with `sponsorGas`, so it's deliberate, not a typo.

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

**Use the single-payee OR P2P variant below based on the user's choice in Step 1.** Only scaffold one.

#### Single-payee variant

On approval, funds go to a configurable `recipient` address (separate from the oracle signer); on rejection, back to the sender. Imports OpenZeppelin's `IERC20` (installed in Preflight).

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

    IERC20 public immutable token;
    address public oracle;
    address public recipient;
    uint256 public nextTransferId;

    mapping(uint256 => Transfer) public transfers;

    event TransferRequested(
        uint256 indexed id,
        address indexed sender,
        uint256 amount
    );
    event TransferApproved(uint256 indexed id);
    event TransferRejected(uint256 indexed id);
    event RecipientUpdated(address indexed oldRecipient, address indexed newRecipient);
    event OracleUpdated(address indexed oldOracle, address indexed newOracle);

    modifier onlyOracle() {
        require(msg.sender == oracle, "not oracle");
        _;
    }

    constructor(address _token, address _oracle, address _recipient) {
        token = IERC20(_token);
        oracle = _oracle;
        recipient = _recipient;
    }

    function requestTransfer(uint256 amount) external {
        require(amount > 0, "zero amount");
        token.transferFrom(msg.sender, address(this), amount);

        uint256 id = nextTransferId++;
        transfers[id] = Transfer({
            sender: msg.sender,
            amount: amount,
            status: Status.Pending
        });

        emit TransferRequested(id, msg.sender, amount);
    }

    function approveTransfer(uint256 id) external onlyOracle {
        Transfer storage t = transfers[id];
        require(t.status == Status.Pending, "not pending");
        t.status = Status.Approved;
        token.transfer(recipient, t.amount);
        emit TransferApproved(id);
    }

    function rejectTransfer(uint256 id) external onlyOracle {
        Transfer storage t = transfers[id];
        require(t.status == Status.Pending, "not pending");
        t.status = Status.Rejected;
        token.transfer(t.sender, t.amount);
        emit TransferRejected(id);
    }

    function setRecipient(address _recipient) external onlyOracle {
        emit RecipientUpdated(recipient, _recipient);
        recipient = _recipient;
    }

    function setOracle(address _oracle) external onlyOracle {
        emit OracleUpdated(oracle, _oracle);
        oracle = _oracle;
    }
}
```

#### Multi-payee (P2P) variant

The sender specifies a recipient per transfer. On approval, funds go to the transfer's `recipient`; on rejection, back to the sender. No `setRecipient` — each transfer carries its own.

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract ComplianceGatedTransfer {
    enum Status { Pending, Approved, Rejected }

    struct Transfer {
        address sender;
        address recipient;
        uint256 amount;
        Status status;
    }

    IERC20 public immutable token;
    address public oracle;
    uint256 public nextTransferId;

    mapping(uint256 => Transfer) public transfers;

    event TransferRequested(
        uint256 indexed id,
        address indexed sender,
        address indexed recipient,
        uint256 amount
    );
    event TransferApproved(uint256 indexed id);
    event TransferRejected(uint256 indexed id);
    event OracleUpdated(address indexed oldOracle, address indexed newOracle);

    modifier onlyOracle() {
        require(msg.sender == oracle, "not oracle");
        _;
    }

    constructor(address _token, address _oracle) {
        token = IERC20(_token);
        oracle = _oracle;
    }

    function requestTransfer(uint256 amount, address _recipient) external {
        require(amount > 0, "zero amount");
        require(_recipient != address(0), "zero recipient");
        token.transferFrom(msg.sender, address(this), amount);

        uint256 id = nextTransferId++;
        transfers[id] = Transfer({
            sender: msg.sender,
            recipient: _recipient,
            amount: amount,
            status: Status.Pending
        });

        emit TransferRequested(id, msg.sender, _recipient, amount);
    }

    function approveTransfer(uint256 id) external onlyOracle {
        Transfer storage t = transfers[id];
        require(t.status == Status.Pending, "not pending");
        t.status = Status.Approved;
        token.transfer(t.recipient, t.amount);
        emit TransferApproved(id);
    }

    function rejectTransfer(uint256 id) external onlyOracle {
        Transfer storage t = transfers[id];
        require(t.status == Status.Pending, "not pending");
        t.status = Status.Rejected;
        token.transfer(t.sender, t.amount);
        emit TransferRejected(id);
    }

    function setOracle(address _oracle) external onlyOracle {
        emit OracleUpdated(oracle, _oracle);
        oracle = _oracle;
    }
}
```

### `contracts/MockUSDC.sol` (testnet / recommended path only)

Native USDC only exists on mainnet. On testnets, deploy this mintable 6-decimal ERC-20 first and use its address as the escrow's `_token` constructor arg. Open `mint` so you can fund sender wallets freely on testnet.

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

  // PLACEHOLDER — mainnet demo escrow (reference-only). REPLACE with your
  // $CONTRACT_ADDRESS in Step 3, or every approveTransfer/rejectTransfer reverts `not oracle`.
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

### `src/lib/mock-screener.ts` (mock mode only)

Use this instead of `webacy.ts` when the user chose mock mode. Same `WalletScreeningResult` interface, no API key needed.

```typescript
import { TaskContext } from "compose";

export type WalletScreeningResult = {
  address: string;
  riskScore: number | null;
  passed: boolean;
  triggeredRules: string[];
};

// Add addresses to this set to simulate flagged/risky wallets
const DENY_LIST = new Set<string>([
  "0x000000000000000000000000000000000000dead",
  // Add your test "risky" addresses here (lowercase)
]);

export async function screenWallet(
  address: string,
  _apiKey: string,
  riskThreshold: number,
  _fetchFn: TaskContext["fetch"],
): Promise<WalletScreeningResult> {
  const isRisky = DENY_LIST.has(address.toLowerCase());

  return {
    address,
    riskScore: isRisky ? 85 : 5,
    passed: !isRisky,
    triggeredRules: isRisky ? ["Deny list match"] : [],
  };
}
```

### `src/lib/screener.ts` (bring-your-own mode only)

Scaffold this interface for the user to implement with their own provider. Same `WalletScreeningResult` interface.

```typescript
import { TaskContext } from "compose";

export type WalletScreeningResult = {
  address: string;
  riskScore: number | null;
  passed: boolean;
  triggeredRules: string[];
};

export async function screenWallet(
  address: string,
  _apiKey: string,
  riskThreshold: number,
  fetchFn: TaskContext["fetch"],
): Promise<WalletScreeningResult> {
  // TODO: Implement your screening logic here.
  // Use fetchFn (not fetch/axios) for any HTTP calls — Compose sandboxes network access.
  //
  // Return { passed: true } to approve, { passed: false } to reject.
  // riskScore and triggeredRules are for audit logging.
  throw new Error("Not implemented — replace with your screening provider");
}
```

> **Provider swap:** all three providers export the same `screenWallet` function signature and `WalletScreeningResult` type. The task imports from whichever provider was chosen — change the import in `on-transfer-requested.ts` to swap: `"../lib/webacy"`, `"../lib/mock-screener"`, or `"../lib/screener"`.

### `src/tasks/on-transfer-requested.ts`

The main task. Decodes the event, screens the sender, signs `approveTransfer`/`rejectTransfer` via the private-key oracle wallet (gas-sponsored), and writes an audit record. **The import path for the screener depends on the provider choice.** The P2P variant differs only in the event type and decoding — see the note after the source.

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
  return `${(Number(raw) / 10 ** CONFIG.usdcDecimals).toFixed(2)} USDC`;
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

> **P2P variant changes:** For the multi-payee contract, change the event type and decoding in `on-transfer-requested.ts`:
> - Event type: `args: { id: bigint; sender: string; recipient: string; amount: bigint }`
> - Add `{ name: "recipient", type: "address", indexed: true }` to the ABI inputs (between sender and amount)
> - Destructure: `const { id, sender, recipient, amount } = decoded.args;`
> - Update `compose.yaml` event signature to `TransferRequested(uint256,address,address,uint256)`
>
> The rest of the task (screening, approve/reject, audit record) is identical — the contract handles routing funds to `transfer.recipient`.

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

## Step 0b — Scaffold the project

Create the directory layout and write each file from **The app (full source)** above — there is nothing to clone.

```bash
mkdir -p compliance-oracle/src/tasks compliance-oracle/src/lib compliance-oracle/contracts
cd compliance-oracle
```

Write these files verbatim from the source above — choose the correct contract variant (single-payee or P2P) and screening provider (webacy.ts, mock-screener.ts, or screener.ts) based on the user's choices in Step 1. Update the import in `on-transfer-requested.ts` to match the chosen provider. Files to write: `compose.yaml`, `tsconfig.json`, `foundry.toml`, `contracts/ComplianceGatedTransfer.sol` (chosen variant), `contracts/MockUSDC.sol` (testnet only), `src/lib/constants.ts`, the chosen screening library, `src/tasks/on-transfer-requested.ts`, and `src/tasks/reconcile.ts`. Then wire the deployed address and chain in Step 3.

Add a `.gitignore`:

```
.env
.compose/
cache/
lib/
out/
node_modules/
```

## Preflight

The `goldsky` CLI and auth checks are the standard Compose preflight — see `/compose` and `/auth-setup`. Compliance-specific:

1. **Compose CLI version (check first).** `goldsky compose --version` must print `0.8.1` or newer, and `deployContract`/`writeContract` must be known commands — everything below (deploys, secrets, smoke test) depends on them. Run:
   ```bash
   goldsky compose --version          # expect: goldsky compose 0.8.1
   goldsky compose deployContract --help >/dev/null 2>&1 && echo "deployContract OK" || echo "deployContract UNKNOWN — CLI too old"
   ```
   If the version is older than `0.8.1` or either command is unknown, **offer** `goldsky compose update` (or `goldsky compose update 0.8.1` for a specific version), run it on confirmation, then re-check before proceeding.
2. **`cast`** — `cast --version`. Install with `curl -L https://foundry.paradigm.xyz | bash && foundryup` if missing. Used only for the `cast` alternative in Step 7 (`forge` is no longer required — `deployContract` compiles in-CLI).
3. **OpenZeppelin contracts** — the escrow imports `IERC20` and MockUSDC imports `ERC20`. The in-CLI solc resolves bare `@openzeppelin/contracts/...` imports by walking up from the source file to `node_modules/`, so install them in the app directory (before the Step 2 deploys — the compiler reads no `foundry.toml` and no `lib/` remappings):
   ```bash
   npm init -y >/dev/null 2>&1 || true   # ensure the app dir is the package root, so npm can't walk up to a parent
   npm install @openzeppelin/contracts
   ```

## Step 1 — Configuration interview

Per the golden rules in `/compose`, ask only what you can't derive, one question at a time — and ask the app name first:

1. **"What should the app be called? (suggest `compliance-oracle`)"** — ask FIRST, before any wallet or contract step. The name is hard to change later: it scopes named wallets and participates in the CREATE2 salt for every `deployContract` (Step 2), so it must be settled now. Accept the default `compliance-oracle` on a shrug, and set it as the top-level `name:` in `compose.yaml`.
2. **"Is this a single-payee system (like a payment gateway or deposit flow) or a multi-payee system (like P2P transfers)?"**
   - **Single payee (recommended for getting started)** — all approved payments go to one configured `recipient` address. The recipient is separate from the oracle and can be updated on the contract independently via `setRecipient()`. Use the single-payee contract variant and `TransferRequested(uint256,address,uint256)` event.
   - **Multi payee (P2P)** — the sender specifies the recipient per transfer. Use the P2P contract variant and `TransferRequested(uint256,address,address,uint256)` event.
3. **"Which compliance/wallet screening API do you want to use?"**
   - **Webacy (recommended)** — simple REST API, one API key. Sign up at https://developers.webacy.co/ — you can create a demo API key right after signup.
   - **Mock mode** — hardcoded allow/deny list, no API key needed. Good for testing the flow before committing to a provider. Remove `WEBACY_API_KEY` from `compose.yaml`'s `secrets` array.
   - **Bring your own** — scaffolds the `screenWallet()` function signature; you fill in the body.
4. **"Which chain?"** — **Base Sepolia (recommended)** — free, gas-sponsored, and you mint your own test USDC. Any EVM chain Compose supports works (Ethereum Sepolia, Polygon Amoy, Arbitrum Sepolia, etc. for testnet; Base, Ethereum, Polygon, Arbitrum, Optimism, etc. for mainnet). Use the camelCase form in TS (`baseSepolia`) and the compose network name in `compose.yaml` (`base_sepolia`).
5. **"What risk threshold?"** — Risk score is 0-100; senders scoring at or above the threshold are rejected. Default `50`. Set `RISK_THRESHOLD` in `src/lib/constants.ts`.
6. **Recipient (single-payee only)** — **"What address should approved payments be sent to?"** They can provide an address now, or use the oracle/deployer wallet address for testing (simplest — "I'll use the oracle wallet for now"). This can be changed later via `setRecipient()` on the contract. The recipient becomes the third constructor arg.

## Step 2 — Oracle wallet and contract deploy

The oracle wallet is a plain EOA private key. Its address becomes the contract's `oracle`, and the same key signs the Compose callbacks at runtime (sponsored). `goldsky compose deployContract` deploys *through the gas-sponsored Compose wallet*, not the oracle key — so the oracle EOA needs no gas for the deploy. Have the user provide `ORACLE_PRIVATE_KEY`, or generate one. **Never print `ORACLE_PRIVATE_KEY`** — generate it straight into a chmod-600 `.env` and show only the derived address:

```bash
# Generate the oracle key WITHOUT printing it: the JSON (which contains the key)
# goes to a temp file, the key is extracted into a chmod-600 .env, and only the
# derived address is ever echoed.
cast wallet new --json > /tmp/k.json
ORACLE_PRIVATE_KEY=$(jq -r '.[0].private_key' /tmp/k.json)
touch .env && chmod 600 .env
printf 'ORACLE_PRIVATE_KEY=%s\n' "$ORACLE_PRIVATE_KEY" >> .env
ORACLE_ADDRESS=$(cast wallet address "$ORACLE_PRIVATE_KEY")
echo "Oracle address: $ORACLE_ADDRESS"   # the ONLY thing ever printed
shred -u /tmp/k.json
```

Also add the RPC URL and screening key to `.env` (never commit this file). Omit `WEBACY_API_KEY` if using mock mode:

```env
RPC_URL=https://sepolia.base.org   # or the RPC for the user's chosen chain; used by the cast alternative in Step 7
WEBACY_API_KEY=your_webacy_api_key  # omit for mock mode
```

`ORACLE_ADDRESS` is already set if you ran the block above; in a fresh shell, re-derive it from `.env` — it is the `oracle` constructor arg, and the contract's `approveTransfer`/`rejectTransfer` must be signed by this same key at runtime:

```bash
source .env
ORACLE_ADDRESS=$(cast wallet address "$ORACLE_PRIVATE_KEY")
```

**Base Sepolia (recommended): deploy a MockUSDC first**, then use its address as the escrow's `_usdc` arg. Both deploys go through the gas-sponsored Compose wallet (Base Sepolia is sponsored, so nothing needs funding) — `deployContract` only changes who deploys; the `oracle` is still the `ORACLE_PRIVATE_KEY` EOA above. (Each `deployContract`/`writeContract` needs a project API key — pass `-t <key>` or have an active `goldsky login` session; generate the key at **Settings > API Keys** in the Goldsky dashboard.)

```bash
# 1) MockUSDC — no constructor args (testnet only)
goldsky compose deployContract contracts/MockUSDC.sol --chain-id $CHAIN_ID
# capture the printed address as $TOKEN_ADDRESS

# 2) ComplianceGatedTransfer — constructor args depend on the payment model:

# Single-payee (3 args: token, oracle, recipient):
goldsky compose deployContract contracts/ComplianceGatedTransfer.sol \
  --chain-id $CHAIN_ID \
  --constructor-args $TOKEN_ADDRESS $ORACLE_ADDRESS $RECIPIENT_ADDRESS

# P2P (2 args: token, oracle):
goldsky compose deployContract contracts/ComplianceGatedTransfer.sol \
  --chain-id $CHAIN_ID \
  --constructor-args $TOKEN_ADDRESS $ORACLE_ADDRESS

# capture the printed address as $CONTRACT_ADDRESS
```

Use the chain ID for the user's chosen chain (e.g. `84532` for Base Sepolia, `8453` for Base mainnet, `11155111` for Ethereum Sepolia, etc.).

The ABI for each contract is auto-saved to `src/contracts/<Name>.json`. Once both deploys print `Address:`, generate the typed contract classes (required before any typecheck — the `tsconfig.json` `paths` entry points at `.compose/types.d.ts`, which codegen produces):

```bash
goldsky compose codegen
```

> **TypeScript pin:** the inlined `tsconfig.json` typechecks on **TypeScript 5.x** — TS 6 rejects `baseUrl`. If you run a typecheck, pin `npx -y typescript@5 tsc` rather than a bare `tsc`.

**Mainnet (production):** skip MockUSDC — use the native token address on the user's chosen chain (e.g. USDC on Base is `0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913`). Ask the user for the token contract address and use it as `$TOKEN_ADDRESS` directly.

Capture `$CONTRACT_ADDRESS` and `$TOKEN_ADDRESS` for the next step, then run `goldsky compose codegen` here too.

## Step 3 — Wire the contract address and chain into the app

Two files reference the chain/addresses. Use grep anchors — line numbers shift.

**`src/lib/constants.ts`:**
- `chain:` → the user's chosen chain in camelCase (e.g. `"baseSepolia"`, `"base"`, `"polygonAmoy"`, etc.).
- `contractAddress:` → `$CONTRACT_ADDRESS`.
- `usdcAddress:` → `$TOKEN_ADDRESS` (your MockUSDC on testnet; native token on mainnet).

**`compose.yaml`** (inside the `on_transfer_requested` trigger):
- `network:` → the compose network name for the user's chain (e.g. `"base_sepolia"`, `"base"`, `"polygon_amoy"`, etc.).
- `contract:` → `$CONTRACT_ADDRESS`.

The event signature should match the chosen contract variant:
- Single-payee: `TransferRequested(uint256,address,uint256)` (already the default)
- P2P: `TransferRequested(uint256,address,address,uint256)`

Show a diff before applying, then apply with Edit.

Note: `src/lib/webacy.ts` hardcodes `?chain=base` in its Webacy request deliberately — testnet screening reuses mainnet reputation data, so leave it `base` even on Base Sepolia (the source comment doesn't say so).

## Step 4 — Set Compose secrets

The running app needs the oracle key (to sign callbacks). If using Webacy, it also needs the API key.

```bash
source .env
goldsky compose secret set ORACLE_PRIVATE_KEY --value "$ORACLE_PRIVATE_KEY"

# Webacy mode only — skip for mock mode:
goldsky compose secret set WEBACY_API_KEY --value "$WEBACY_API_KEY"
```

If using Webacy and you haven't signed up yet, do it now at https://developers.webacy.co/ — you can create a demo API key right after signup.

## Step 5 — Optional: publish to a new GitHub repo

```bash
git init
git add .
if git ls-files --cached | grep -qiE '(\.env$|private[._-]?key|\.pem|id_rsa)'; then
  echo "⚠ Secret-shaped file is staged — remove it before committing. Aborting publish."
else
  git commit -m "Initial commit: Compose compliance-oracle"
  gh repo create <user's repo name> --<public|private> --source=. --push
fi
```

(The `.gitignore` from Step 0b excludes `.env`; the grep is a backstop — never commit the oracle key.)

## Step 6 — Deploy to Goldsky

```bash
goldsky compose deploy
```

First deploy may take 1-2 minutes. Watch for `Deployed compose app: <the chosen app name>` (e.g. `compliance-oracle`). The `on_transfer_requested` event listener and the `reconcile` cron both go live.

## Step 7 — Smoke test

This step runs **after** `compose deploy` (Step 6), so the app's wallets now exist. The **primary** path drives the whole flow from the app's gas-sponsored default smart wallet via `writeContract` — no funded EOA needed. (A `cast` alternative with your own EOA follows.)

**Primary — sponsored `writeContract` from the app wallet.** List the app's wallets and grab the default smart wallet as the sender:

```bash
goldsky compose wallet list
# set $COMPOSE_WALLET to the app's default smart wallet address
```

Then mint, approve, and request the transfer (each needs `-t <project API key>` or an active `goldsky login` session):

```bash
# mint 1.00 mUSDC to the app wallet (MockUSDC.mint is open)
goldsky compose writeContract --chain-id 84532 --to $USDC_ADDRESS \
  --function "mint(address,uint256)" --args $COMPOSE_WALLET 1000000

# approve the escrow to pull the app wallet's USDC
goldsky compose writeContract --chain-id 84532 --to $USDC_ADDRESS \
  --function "approve(address,uint256)" --args $CONTRACT_ADDRESS 1000000

# request a 1.00 USDC transfer — emits TransferRequested, which the task screens
goldsky compose writeContract --chain-id 84532 --to $CONTRACT_ADDRESS \
  --function "requestTransfer(uint256)" --args 1000000
```

> **Why this works without the oracle key:** `MockUSDC.mint` is open; both `approve` and `requestTransfer` are sent from the same app wallet, and `requestTransfer` pulls via `transferFrom` from `msg.sender` — so the sender does not need to be the oracle. The oracle key only signs the `approveTransfer`/`rejectTransfer` callback at runtime.

Then **stream** the logs and watch the decision land (bare `goldsky compose logs` is a one-shot dump; add `-f`/`--follow` to watch the next fire):

```bash
goldsky compose logs -f
```

**What to look for:** `deposit received`, `screening complete ... risk score N`, then `transfer #<id> APPROVED` (or a reject warning) with an `oracleTxHash`. Verify on-chain — `transfers(<id>)` status should be `1` (Approved) or `2` (Rejected), not `0`:

```bash
cast call $CONTRACT_ADDRESS "transfers(uint256)(address,uint256,uint8)" <id> --rpc-url $RPC_URL
```

**Alternative — `cast` from your own funded EOA.** If you'd rather drive the flow with a separate sender key (`$SENDER_KEY`, not the oracle), it is **not** gas-sponsored, so fund it first: get Base Sepolia ETH from a faucet (e.g. https://www.coinbase.com/faucets/base-sepolia) into `$SENDER_ADDRESS`, then:

```bash
# mint is open — any funded key mints to the sender
cast send $USDC_ADDRESS "mint(address,uint256)" $SENDER_ADDRESS 1000000 \
  --rpc-url $RPC_URL --private-key $SENDER_KEY   # 1.00 mUSDC
# approve the escrow, then request (ERC-20 needs prior approval)
cast send $USDC_ADDRESS "approve(address,uint256)" $CONTRACT_ADDRESS 1000000 \
  --rpc-url $RPC_URL --private-key $SENDER_KEY
cast send $CONTRACT_ADDRESS "requestTransfer(uint256)" 1000000 \
  --rpc-url $RPC_URL --private-key $SENDER_KEY
```

Generate `$SENDER_KEY` the same no-echo way as the oracle key (never print it): `cast wallet new --json > /tmp/s.json; SENDER_KEY=$(jq -r '.[0].private_key' /tmp/s.json); SENDER_ADDRESS=$(cast wallet address "$SENDER_KEY"); echo "$SENDER_ADDRESS"; shred -u /tmp/s.json`.

## Troubleshooting

- **`error: Unknown command "deployContract". Did you mean command "deploy"?` (or the `writeContract` variant).** Compose CLI is older than 0.8.1. Run `goldsky compose update` (or `goldsky compose update 0.8.1`), confirm `goldsky compose --version` prints `0.8.1`+, then retry.
- **Edits to `compose.yaml` or source files don't take effect after redeploy.** Stale `.compose/` bundle cache. Run `rm -rf .compose/` and redeploy.
- **`approveTransfer`/`rejectTransfer` reverts with `not oracle`.** The Compose wallet's address doesn't match the contract's `oracle`. They must derive from the same `ORACLE_PRIVATE_KEY`. Check: `cast call $CONTRACT_ADDRESS "oracle()(address)" --rpc-url $RPC_URL` should equal `cast wallet address $ORACLE_PRIVATE_KEY`.
- **`requestTransfer` reverts with "transfer amount exceeds allowance".** The sender didn't `approve` the escrow to spend their USDC first. Run the `approve` call before `requestTransfer`.
- **Task never fires when a transfer is requested.** Confirm `compose.yaml`'s `contract:` and `network:` match where you deployed, the deploy succeeded, and the trigger is active (`goldsky compose status`). Wiring only one of `chain` (constants.ts) / `network` (compose.yaml) is the usual cause.
- **Webacy returns an empty response / task throws.** Check `WEBACY_API_KEY` is set as a secret and valid, and the address is well-formed hex. Transient failures are absorbed by the `retry_config` (3 attempts, backoff).
- **Reject scenario approves instead.** On Base Sepolia, a fresh test wallet has no on-chain history, so Webacy scores it low (it passes). Use a known-flagged address, or test the reject path on mainnet where real risk data exists.
- **`insufficient funds for gas` on deploy.** On Base / Base Sepolia the deploy is sponsored. On other chains, fund the **Compose wallet** (the deployer — not the oracle key) with native gas; the `ORACLE_PRIVATE_KEY` EOA needs nothing.
- **Re-running `deployContract` with identical contract + args + app is refused ("This contract has already been deployed with this app...").** This is a CREATE2 pre-tx refusal — it prints **no** `Deploy Block:`. The address is deterministic from contract code + constructor args + app name + project, so an identical combination reproduces the same address. Fresh-deploy levers: change a constructor arg, change the source, or use a different app name. For the no-arg `MockUSDC` the **only** lever is the app name; for `ComplianceGatedTransfer` (takes `(usdc, oracle)`) changing a constructor arg also works. ⚠ Renaming the app changes **all** future deploy addresses and conflicts with the `compose deploy` app name, so prefer the constructor-arg lever where possible — for no-arg contracts the app-name lever is the only option.

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
