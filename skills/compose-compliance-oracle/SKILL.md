---
name: compose-compliance-oracle
description: "Build and deploy a compliance-gated payment system with Goldsky Compose — a smart contract holds funds in escrow while Compose screens the sender via a compliance API (Webacy recommended), then calls back to approve (funds to recipient) or reject (funds returned to sender). Supports two contract modes: single-payee (payment gateway / deposit flow with a configurable recipient) and multi-payee (P2P transfers where the sender specifies the recipient). Triggers on: 'build a compliance oracle', 'compliance-gated payments', 'AML screening onchain', 'KYC payment gateway', 'escrow with compliance check', 'wallet screening oracle', 'build a payment gateway with compliance', 'gated transfers', 'Webacy oracle'. Default path is local TEVM fork (zero friction, agent automates everything); graduates to testnet then mainnet. Uses a single onchain_event task (on-transfer-requested). For a custom/novel Compose app, use /compose. For debugging, use /compose-doctor. For manifest/CLI/API lookups, use /compose-reference."
---

# Build: Compose Compliance Oracle

Build a compliance-gated payment system where a smart contract holds funds in escrow, Compose screens the sender wallet via a compliance API, then calls back to approve or reject the transfer. Approved funds go to the intended recipient; rejected funds return to the sender automatically. Gas is sponsored — the oracle wallet never needs native token.

## Mode Detection

Pick the mode from the tools available to you:

- **A `deployComposeApp` tool is available (Goldsky webapp chatbot):** Give a 2-3 sentence explanation, then ask the config questions one at a time with `askUser`. After the interview, **first load `/compose-reference`** for the manifest schema and sandbox import rule, scaffold the files following them, then **call `deployComposeApp`** in the same turn. After the deploy card, tell the user they still need to set secrets (`ORACLE_PRIVATE_KEY` and optionally `WEBACY_API_KEY`) via the dashboard or CLI. **Ignore the Steps below** — they are the CLI/local procedure.
- **`Bash` is available (local CLI / coding agent):** Execute the steps below directly, parse output, and substitute captured values into later commands.
- **Neither (pure reference Q&A):** Explain what the app does; only if asked for steps, output one command at a time. Point them at `npx skills add goldsky-io/goldsky-agent` to run it locally with Bash.

## Non-negotiables

- **Never run `forge create`, `goldsky compose deploy`, `git push`, or `gh repo create` without showing the exact command first and getting explicit confirmation.**
- **The oracle wallet (Compose wallet) is the signer for approve/reject calls. It is NOT the payment recipient** (unless the user explicitly wants that). The contract separates these roles.
- **Gas sponsorship:** The Compose wallet uses `sponsorGas: true` — it never needs native token for gas. This works on both fork and sponsored chains.
- **Do not import external packages.** `evm`, `fetch`, `collection`, `env`, and `logger` all come from the injected `context` argument. The only import allowed is `compose` (for types) and sibling project files.

## Variable handling for agents

When this skill says `$FOO`, capture the literal value from the prior command's output and substitute it directly into the next command. Do not rely on shell variables persisting between separate Bash tool invocations — each invocation gets a fresh shell.

## Preflight

1. **`goldsky` CLI** — `goldsky --version`. Install per https://docs.goldsky.com/reference/cli.
2. **`goldsky` authenticated** — `goldsky project list`. If it errors, tell the user: "Please run `goldsky login` in your terminal. Tell me to continue when you see the success message." Do not spawn `goldsky login` from Bash; it requires an interactive browser.
3. **`forge` + `cast`** — `forge --version`. Install with `curl -L https://foundry.paradigm.xyz | bash && foundryup` if missing. Required for contract deployment.

## Step 1 — Configuration Interview

Ask these questions one at a time. Use readable labels and translate to machine values yourself.

### 1a. Payment model

> **"Is this a single-payee system (like a payment gateway or deposit flow) or a multi-payee system (like P2P transfers)?"**

- **Single payee (recommended for getting started)** — All approved payments go to one configured recipient address. The recipient can be updated on the contract independently. `requestTransfer(uint256 amount)` — no recipient param.
- **Multi payee (P2P)** — The sender specifies the recipient per transfer. `requestTransfer(uint256 amount, address recipient)` — recipient stored per transfer.

This choice determines which contract variant and event signature to use.

### 1b. Compliance provider

> **"Which compliance/wallet screening API do you want to use?"**

- **Webacy (recommended)** — Simple REST API, one API key. Sign up at https://developers.webacy.co/ — you can create a demo API key right after signup. Screens wallets for risk score (0-100 scale).
- **Bring your own** — You provide your own screening endpoint or logic. The skill scaffolds the `screenWallet()` function signature; you fill in the body.
- **Mock mode** — Hardcoded allow/deny list, no API key needed. Good for testing the flow before committing to a provider. Any address you add to the deny list gets rejected; everything else passes.

### 1c. Deployment target

> **"Where do you want to run this?"**

- **Local TEVM fork (recommended for getting started)** — Zero cost, instant, no external dependencies. The agent handles everything: deploying the contract, constructing test payloads, and running the full flow. Start here, then graduate to testnet/mainnet.
- **Testnet (Base Sepolia)** — Real chain with real event triggers. Requires a wallet with testnet ETH (free from faucets). Gas-sponsored for the Compose wallet.
- **Mainnet (Base)** — Production. Real USDC, real compliance screening. Requires funded wallets.

### 1d. App name

> **"What should we name the Compose app?"** (recommend `compliance-oracle`)

### 1e. Payment recipient (single-payee mode only)

> **"What address should approved payments be sent to?"**

- They can provide an address now
- Or use the oracle/deployer wallet address (simplest for testing — "I'll use the deployer wallet for now")
- This can be changed later via `setRecipient()` on the contract

### 1f. Token (if testnet or mainnet)

> **"Which ERC-20 token for payments?"**

- **Testnet:** Recommend MockUSDC or any mintable test token
- **Mainnet:** USDC on Base (`0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913`, 6 decimals)

For local fork: use USDC on Base (the fork will have the real USDC contract available).

## Step 2 — Scaffold the Project

Create the project directory and files:

```bash
mkdir -p compliance-oracle/src/tasks compliance-oracle/src/lib compliance-oracle/contracts
cd compliance-oracle
```

### compose.yaml

**Single-payee variant:**
```yaml
name: "$APP_NAME"
api_version: "internal-pk-sponsored-otel"

secrets:
  - ORACLE_PRIVATE_KEY
  # Include WEBACY_API_KEY only if using Webacy provider
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
        network: "$NETWORK"
        contract: "$CONTRACT_ADDRESS"
        events:
          - "TransferRequested(uint256,address,uint256)"
```

**Multi-payee (P2P) variant** — same except the event signature:
```yaml
        events:
          - "TransferRequested(uint256,address,address,uint256)"
```

For local fork: `$CONTRACT_ADDRESS` can be a placeholder (`0x0000000000000000000000000000000000000000`) — it will be updated after deployment. `$NETWORK` should match the chain being forked (e.g. `base`).

### tsconfig.json

```json
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "ES2022",
    "moduleResolution": "bundler",
    "strict": true,
    "esModuleInterop": true,
    "skipLibCheck": true
  },
  "include": ["src/**/*.ts"]
}
```

## Step 3 — Write the Contract

### Single-payee contract: `contracts/ComplianceGatedTransfer.sol`

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

### Multi-payee (P2P) contract: `contracts/ComplianceGatedTransfer.sol`

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

### Install OpenZeppelin (needed for compilation)

```bash
forge install OpenZeppelin/openzeppelin-contracts --no-commit
```

Write a minimal `foundry.toml`:

```toml
[profile.default]
src = "contracts"
libs = ["lib"]
```

## Step 4 — Write the Screening Library

### Webacy provider: `src/lib/webacy.ts`

```typescript
import type { TaskContext } from "compose";

export type WalletScreeningResult = {
  address: string;
  riskScore: number | null;
  passed: boolean;
  triggeredRules: string[];
};

export async function screenWallet(
  address: string,
  apiKey: string,
  riskThreshold: number,
  fetchFn: TaskContext["fetch"],
): Promise<WalletScreeningResult> {
  const url = `https://api.webacy.com/addresses/${address}?chain=base`;

  const data = await fetchFn<{
    overallRisk: number;
    issues: { score: number; tags: { name: string; severity: number }[] }[];
  }>(url, {
    method: "GET",
    headers: { "x-api-key": apiKey },
  });

  if (!data) {
    throw new Error(`Webacy API returned empty response for ${address}`);
  }

  const riskScore = data.overallRisk ?? null;
  const triggeredRules = (data.issues ?? [])
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

### Bring-your-own provider: `src/lib/screener.ts`

Scaffold this interface for the user to implement:

```typescript
import type { TaskContext } from "compose";

export type WalletScreeningResult = {
  address: string;
  riskScore: number | null;
  passed: boolean;
  triggeredRules: string[];
};

export async function screenWallet(
  address: string,
  env: Record<string, string>,
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

### Mock provider: `src/lib/mock-screener.ts`

```typescript
import type { TaskContext } from "compose";

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
  _env: Record<string, string>,
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

## Step 5 — Write the Constants

### `src/lib/constants.ts`

```typescript
import type { Hex } from "compose";

export const CONFIG = {
  chain: "$CHAIN" as const,  // "base", "baseSepolia", etc.
  contractAddress: "$CONTRACT_ADDRESS" as Hex,
  tokenAddress: "$TOKEN_ADDRESS" as Hex,
  tokenDecimals: 6,
};

// Webacy risk score threshold (0-100 scale)
// Wallets scoring above this are rejected
export const RISK_THRESHOLD = 50;
```

## Step 6 — Write the Task

### Single-payee: `src/tasks/on-transfer-requested.ts`

```typescript
import { TaskContext, OnchainEvent } from "compose";
import { CONFIG, RISK_THRESHOLD } from "../lib/constants";
import { screenWallet } from "../lib/webacy";  // or mock-screener or screener

type TransferAuditRecord = {
  transferId: string;
  sender: string;
  amount: string;
  screening: { riskScore: number | null; passed: boolean; triggeredRules: string[] };
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

function formatToken(raw: bigint, decimals: number): string {
  return (Number(raw) / 10 ** decimals).toFixed(decimals);
}

export async function main(ctx: TaskContext, payload: OnchainEvent) {
  const { evm, collection, env, fetch: ctxFetch } = ctx;
  const log = ctx.logger;

  // --- Decode the onchain event ---
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
  const depositTxHash = (payload as any).transactionHash;

  log.info(`Transfer #${transferId}: ${formatToken(amount, CONFIG.tokenDecimals)} from ${sender}`);

  // --- Screen the sender ---
  log.info(`Screening sender ${sender}`);
  const screenResult = await screenWallet(sender, env.WEBACY_API_KEY, RISK_THRESHOLD, ctxFetch);
  log.info(`Screening complete: risk score ${screenResult.riskScore}`);

  // --- Call back to the contract ---
  const wallet = await evm.wallet({ privateKey: env.ORACLE_PRIVATE_KEY, sponsorGas: true });

  let txHash: string;
  let decision: "approved" | "rejected";
  let reason: string;

  if (screenResult.passed) {
    decision = "approved";
    reason = `Risk score ${screenResult.riskScore} below threshold ${RISK_THRESHOLD}`;
    log.info(`Approving transfer #${transferId}`);

    const result = await wallet.writeContract(
      evm.chains[CONFIG.chain],
      CONFIG.contractAddress,
      "approveTransfer(uint256)",
      [id],
    );
    txHash = result.hash;
    log.info(`Transfer #${transferId} APPROVED`, { oracleTxHash: txHash });
  } else {
    decision = "rejected";
    reason = `Risk score ${screenResult.riskScore}, rules: ${screenResult.triggeredRules.join(", ")}`;
    log.warn(`Rejecting transfer #${transferId}`);

    const result = await wallet.writeContract(
      evm.chains[CONFIG.chain],
      CONFIG.contractAddress,
      "rejectTransfer(uint256)",
      [id],
    );
    txHash = result.hash;
    log.info(`Transfer #${transferId} REJECTED`, { oracleTxHash: txHash });
  }

  // --- Persist audit record ---
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

  log.info(`Audit record saved for transfer #${transferId}`);
  return { transferId, decision, reason, oracleTxHash: txHash };
}
```

### Multi-payee (P2P): `src/tasks/on-transfer-requested.ts`

Same as above but with the P2P event signature — add `recipient` to the decoded args:

```typescript
// Change the event type:
type TransferRequestedEvent = {
  eventName: "TransferRequested";
  args: { id: bigint; sender: string; recipient: string; amount: bigint };
};

// Change the ABI in decodeEventLog:
const decoded = await evm.decodeEventLog<TransferRequestedEvent>(
  [{
    type: "event",
    name: "TransferRequested",
    inputs: [
      { name: "id", type: "uint256", indexed: true },
      { name: "sender", type: "address", indexed: true },
      { name: "recipient", type: "address", indexed: true },
      { name: "amount", type: "uint256", indexed: false },
    ],
  }],
  payload,
);

const { id, sender, recipient, amount } = decoded.args;
```

The rest of the task logic (screening, approve/reject, audit record) is identical — the contract handles routing funds to the correct recipient.

## Step 7 — Deploy the Contract

### Path A: Local TEVM fork (recommended)

Start the Compose app in fork mode first:

```bash
goldsky compose start --fork-chains
```

In a second terminal, deploy the contract to the fork. Use a deterministic test private key:

```bash
# Test private key (DO NOT use on mainnet — this is a well-known key for local dev)
export TEST_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
```

**Single-payee deployment** (3 constructor args: token, oracle, recipient):

```bash
# Derive the oracle address
ORACLE_ADDR=$(cast wallet address $TEST_KEY)

forge create contracts/ComplianceGatedTransfer.sol:ComplianceGatedTransfer \
  --rpc-url http://127.0.0.1:8545 \
  --private-key $TEST_KEY \
  --broadcast \
  --constructor-args $TOKEN_ADDRESS $ORACLE_ADDR $RECIPIENT_ADDRESS
```

**Multi-payee deployment** (2 constructor args: token, oracle):

```bash
ORACLE_ADDR=$(cast wallet address $TEST_KEY)

forge create contracts/ComplianceGatedTransfer.sol:ComplianceGatedTransfer \
  --rpc-url http://127.0.0.1:8545 \
  --private-key $TEST_KEY \
  --broadcast \
  --constructor-args $TOKEN_ADDRESS $ORACLE_ADDR
```

Capture `Deployed to: 0x...` as `$CONTRACT_ADDRESS`. Update `src/lib/constants.ts` with this address.

For local fork with USDC on Base, `$TOKEN_ADDRESS` is `0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913`.

For `$RECIPIENT_ADDRESS` in single-payee mode: use whatever the user specified in Step 1e. If they said "use the deployer wallet," use `$ORACLE_ADDR`.

### Path B: Testnet (Base Sepolia)

Same `forge create` commands but with:
- `--rpc-url https://sepolia.base.org`
- A private key with testnet ETH
- A test ERC-20 token address for the `$TOKEN_ADDRESS`

### Path C: Mainnet (Base)

Same `forge create` commands but with:
- `--rpc-url https://mainnet.base.org`
- A funded private key (**never share or commit this key**)
- USDC: `0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913`

## Step 8 — Set Secrets and Configure

### Local fork

Create a `.env` file in the project root:

```env
ORACLE_PRIVATE_KEY=$TEST_KEY
WEBACY_API_KEY=your_webacy_api_key_here
```

If using mock mode, omit `WEBACY_API_KEY` (and remove it from `compose.yaml`'s `secrets` array).

### Testnet / Mainnet

```bash
goldsky compose secret set ORACLE_PRIVATE_KEY --value $ORACLE_PRIVATE_KEY
goldsky compose secret set WEBACY_API_KEY --value $WEBACY_API_KEY
```

## Step 9 — Smoke Test

### Local fork smoke test

Since onchain event triggers don't fire on the local TEVM fork yet (see FOU-979), use `callTask` with a constructed event payload.

**Construct the callTask payload:**

The agent should compute the correct ABI-encoded payload for the `TransferRequested` event. The event has:
- `topic0`: keccak256 hash of the event signature
- `topic1`: the transfer ID (uint256, zero-padded to 32 bytes)
- `topic2`: the sender address (zero-padded to 32 bytes)
- For P2P: `topic3`: the recipient address (zero-padded to 32 bytes)
- `data`: ABI-encoded non-indexed params (amount as uint256)

Use `cast` to compute these values:

```bash
# Compute topic0 for single-payee
TOPIC0=$(cast keccak "TransferRequested(uint256,address,uint256)")

# For P2P:
# TOPIC0=$(cast keccak "TransferRequested(uint256,address,address,uint256)")

# Encode a test transfer ID (0) as topic1
TOPIC1=$(cast to-uint256 0 | cast to-bytes32)

# Encode a test sender as topic2 (pad address to 32 bytes)
SENDER="0x70997970C51812dc3A010C7d01b50e0d17dc79C8"
TOPIC2=$(cast abi-encode "x(address)" $SENDER | cut -c3-)
TOPIC2="0x$TOPIC2"

# Encode amount as data (e.g., 1 USDC = 1000000)
DATA=$(cast abi-encode "x(uint256)" 1000000)
```

Then call the task:

```bash
goldsky compose callTask on_transfer_requested "{
  \"blockNumber\": 1,
  \"blockHash\": \"0x$(printf '0%.0s' {1..64})\",
  \"transactionIndex\": 0,
  \"removed\": false,
  \"address\": \"$CONTRACT_ADDRESS\",
  \"data\": \"$DATA\",
  \"topics\": [\"$TOPIC0\", \"$TOPIC1\", \"$TOPIC2\"],
  \"transactionHash\": \"0x$(printf 'a%.0s' {1..64})\",
  \"logIndex\": 0
}"
```

**What to look for:**
- Task logs show "Screening sender..." and a risk score
- Task logs show "APPROVED" or "REJECTED" depending on the sender's risk
- An audit record is saved to the `transfer-audits` collection
- If approved, the oracle tx hash is logged

### Testnet / Mainnet smoke test

Deploy the Compose app:

```bash
goldsky compose deploy
```

Then trigger a real transfer by having a test wallet call `requestTransfer()` on the contract:

```bash
# First approve the contract to spend tokens
cast send $TOKEN_ADDRESS "approve(address,uint256)" $CONTRACT_ADDRESS 1000000 \
  --rpc-url $RPC_URL --private-key $SENDER_KEY

# Then request a transfer
cast send $CONTRACT_ADDRESS "requestTransfer(uint256)" 1000000 \
  --rpc-url $RPC_URL --private-key $SENDER_KEY

# For P2P: cast send $CONTRACT_ADDRESS "requestTransfer(uint256,address)" 1000000 $RECIPIENT \
#   --rpc-url $RPC_URL --private-key $SENDER_KEY
```

Tail logs to watch the task fire:

```bash
goldsky compose logs
```

Verify on-chain: check the contract for `TransferApproved` or `TransferRejected` events on the block explorer.

## Troubleshooting

- **Edits to source files don't take effect.** Stale `.compose/` bundle cache. Run `rm -rf .compose/` and restart/redeploy.
- **`approveTransfer` or `rejectTransfer` reverts with "not oracle".** The Compose wallet address doesn't match the contract's `oracle`. Check `cast call $CONTRACT "oracle()(address)" --rpc-url $RPC` and compare to the wallet address in the Compose logs.
- **`requestTransfer` reverts with "transfer amount exceeds allowance".** The sender hasn't approved the contract to spend their tokens. Run the `approve` call first.
- **Webacy returns empty response.** Check the API key is valid and the address format is correct (checksummed or lowercase hex).
- **Mock screener always approves.** Add the test sender's address (lowercase) to the `DENY_LIST` set in `mock-screener.ts`.
- **Local fork: contract not found.** The fork state resets between restarts. Redeploy the contract after each `compose start --fork-chains`. (FOU-979 will add state persistence to fix this.)
- **Local fork: event trigger doesn't fire.** Expected — local fork event triggers are not yet implemented (FOU-979). Use `callTask` with a constructed payload as shown in Step 9.

## What you should NOT do

- Do not import `viem`, `ethers`, or any external package in the task code. Use `evm.chains`, `evm.wallet`, and `evm.decodeEventLog` from the context.
- Do not use the oracle/Compose wallet as the payment recipient unless the user explicitly wants that. The contract separates signer from recipient.
- Do not hardcode the compliance provider — use the screening library abstraction so providers are swappable.
- Do not skip the `approve` step when testing — ERC-20 transfers require prior approval of the contract as a spender.

## Graduating from local to production

1. **Local fork** → Build and test the screening + callback logic with `callTask`
2. **Testnet** → Deploy contract to Base Sepolia, deploy Compose app, test with real event triggers end-to-end
3. **Mainnet** → Same contract and app code, just update chain/addresses/secrets for production

The task code is identical across all environments. Only `constants.ts`, `compose.yaml`, and secrets change.

## Related

- **`/compose`** — Build a new/custom Compose app from scratch, or explain what Compose is.
- **`/compose-reference`** — Manifest, CLI, TaskContext API, wallets, gas sponsorship, codegen.
- **`/compose-doctor`** — Diagnose and fix a broken Compose app.
- **`/compose-local-test`** — Local TEVM fork testing guide (fork + impersonate).
