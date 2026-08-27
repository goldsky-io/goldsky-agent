---
name: compose-compliance-oracle
description: "Build and deploy the Goldsky Compose compliance-oracle example under the user's own account — a compliance-gated payment system where a smart contract holds funds in escrow, Compose screens the sender wallet via a compliance API (Webacy recommended, or bring-your-own / mock), then calls back to approve or reject. Supports two payment models: single-payee (payment gateway — funds go to a configurable recipient) and multi-payee (P2P — sender specifies recipient per transfer). Ships a second cron task that reconciles stuck transfers. Triggers on: 'build a compliance oracle', 'compliance-gated payments', 'AML screening onchain', 'KYC payment gateway', 'escrow with compliance check', 'wallet screening oracle', 'gated transfers', 'Webacy oracle', 'P2P compliance', 'payment gateway with screening'. The escrow contract's approve/reject are oracle-permissioned, so there is no shared no-deploy contract — each user deploys their own instance bound to their oracle wallet (recommended path: Base Sepolia + a MockUSDC). The oracle is a named Compose smart wallet (`compliance-oracle-wallet`, gas-sponsored) with no private key to manage on the default path. For a custom/novel Compose app, use /compose. For debugging a deployed app, use /compose-doctor. For manifest/CLI/API field lookups, use /compose-reference."
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

- **A `deployComposeApp` tool is available (Goldsky webapp chatbot).** Compliance now deploys fully in-app. In-app flow: run the Step 1 interview (app name first), `walletCreate({ appName: "<chosen app name>", walletName: "compliance-oracle-wallet" })` to get the oracle wallet address (pass `appName` as the chosen app name and `walletName` explicitly; passing the wallet name positionally as `appName` creates the wrong app scope, and the resulting address never matches the runtime `evm.wallet({ name: "compliance-oracle-wallet" })`), `deployContract` MockUSDC, then `deployContract` ComplianceGatedTransfer with `constructorArgs: ["<token_addr>", "<oracle-wallet-addr>", "<recipient_addr>"]` for single-payee or `["<token_addr>", "<oracle-wallet-addr>"]` for P2P (these are tool inputs: `sources` and `constructorArgs`, not CLI flags). Wire the deployed contract address and chain into the inlined source (Step 3), then `deployComposeApp`. The `WEBACY_API_KEY` secret is the user's LAST step: the in-app deploy skips secret validation, so `deployComposeApp` succeeds without it, but the app won't run until the user adds the secret in the Compose app's dashboard **and redeploys from the dashboard** so the pod picks it up (secrets are baked into the pod at deploy, not hot-reloaded). NEVER attempt to set a secret from chat; there is no tool, by design. Scaffold the inlined source from **The app (full source)** below in-memory.
  - **Testing in webapp mode:** After deploy succeeds, **always proactively walk the user through the smoke test** (Step 7). The smoke test requires `goldsky compose writeContract` (a CLI command). Before giving the commands, ask the user if they have the Goldsky CLI installed. If they don't, walk them through installing it first:
    ```
    curl https://goldsky.com | sh
    goldsky compose install
    goldsky login
    ```
    Then proceed with the Step 7 smoke test commands. Do NOT skip the smoke test or wait for the user to ask — deploying without testing leaves the user unsure whether the app actually works.
- **`Bash` is available (local CLI / coding agent):** execute the steps below directly, parse output, and substitute captured values into later commands.
- **Neither (pure reference Q&A):** explain what the app does and the escrow → screen → approve/reject lifecycle; only if asked for step-by-step help, output one command at a time and have the user paste output back. Point them at `npx skills add goldsky-io/goldsky-agent` to run it locally with Bash.

## Variable handling for agents

When this skill says `$FOO`, capture the literal value from the prior command's output and substitute it directly into the next command. Do not rely on shell variables persisting between separate Bash tool invocations — each invocation gets a fresh shell. **Exception, secret values:** never capture `WEBACY_API_KEY`, `ORACLE_PRIVATE_KEY` (BYO-key path), or any `*_KEY` value into your context or substitute it literally into a command. Have the user export the value in their shell (or write it into a chmod-600 `.env` themselves) and reference it with `"$VAR"` expansion inside a single Bash invocation — never paste it into the chat or echo it back.

## Non-negotiables

- **There is no shared, reusable contract.** `approveTransfer`, `rejectTransfer`, and `setOracle` are all `onlyOracle` (`require(msg.sender == oracle)`), and `oracle` is fixed at construction. A user cannot point their app at someone else's deployed instance — only that instance's oracle key can sign valid callbacks. Every user deploys their own via Step 2. (An older demo instance exists on Base **mainnet** at `0x39efE8A851A4Da22fa40828F6D4b3DC6b54545Aa`, but its oracle is a fixed key nobody else holds, so it is reference-only, not reusable.)
- **The oracle is the Compose smart wallet `compliance-oracle-wallet`.** Its address IS the contract's `oracle` constructor arg. Capture the address from `walletCreate({ appName: "<chosen app name>", walletName: "compliance-oracle-wallet" })` (in-app; `appName` is the chosen app name, `walletName` is explicit) or `goldsky compose wallet create compliance-oracle-wallet` (CLI), and pass it as the second constructor arg to `ComplianceGatedTransfer`. The Compose task loads the same wallet via `evm.wallet({ name: "compliance-oracle-wallet", sponsorGas: true })`. If they don't match, every `approveTransfer`/`rejectTransfer` reverts with `not oracle`. Gas is sponsored, no private key to manage.
- **Gas sponsorship:** the oracle wallet uses `sponsorGas: true`, so it never needs native token for gas on sponsored chains (Base, Base Sepolia). `goldsky compose deployContract` deploys through the gas-sponsored Compose wallet, so neither the deploy nor the runtime callbacks cost the oracle anything.
- **`WEBACY_API_KEY` is a real secret.** Never print, commit, or log it — Compose secrets only, never echoed back or substituted literally into a command or the transcript. On the Advanced BYO-key path, treat `ORACLE_PRIVATE_KEY` with the same discipline.
- **Do not import external packages in task code.** `evm`, `fetch`, `collection`, `env`, and `logger` all come from the injected `context` argument. The only import allowed in tasks is `compose` (for types) and sibling project files.
- **Never run `goldsky compose deployContract`, `goldsky compose deploy`, `goldsky compose secret set`, `git push`, or `gh repo create` without showing the exact command first and getting explicit confirmation.**

## Advanced: bring your own oracle key (production)

The default path uses a gas-sponsored Compose smart wallet (`compliance-oracle-wallet`) with no key to manage. If you need your own key custody (for example, a production signer you control), you can bring your own EOA private key instead:

- Set `ORACLE_PRIVATE_KEY` as a Compose secret: `goldsky compose secret set ORACLE_PRIVATE_KEY --value "$ORACLE_PRIVATE_KEY"` (exported by the user in their own shell — never paste the literal key). Never print, commit, or log this key.
- In `compose.yaml`, add `ORACLE_PRIVATE_KEY` to the `secrets:` block and set `api_version: "internal-pk-sponsored-otel"` (the internal channel is required for BYO-private-key combined with `sponsorGas`).
- In the task source, load the wallet with `evm.wallet({ privateKey: env.ORACLE_PRIVATE_KEY, sponsorGas: true })` instead of the named `compliance-oracle-wallet`.
- The contract's `oracle` constructor arg is `cast wallet address $ORACLE_PRIVATE_KEY`.

This is not the default; most users should use the Compose smart wallet.

## The app (full source)

This is the complete compliance app. Scaffold these files verbatim (Step 0b writes them to disk; the in-app flow scaffolds them in-memory) — there is nothing to clone. ⚠ The addresses shipped in `compose.yaml` and `src/lib/constants.ts` below (`contract:` and `contractAddress:` both default to the mainnet demo escrow `0x39efE8A851A4Da22fa40828F6D4b3DC6b54545Aa`) are **placeholders** — Step 3 wiring is **MANDATORY** before deploy; unwired, every callback reverts `not oracle`. Only edit those two files to wire in your deployed contract address and chain. The source below is pointed at Base **mainnet** with native USDC — the recommended getting-started path swaps that to Base Sepolia + a MockUSDC in Step 3.

### `compose.yaml`

```yaml
name: "compliance-oracle"
api_version: "stable"

secrets:
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

**Use the single-payee OR P2P variant below based on the user's choice in Step 1.** Only scaffold one.

#### Single-payee variant

On approval, funds go to a configurable `recipient` address (separate from the oracle signer); on rejection, back to the sender. The `IERC20` interface is inlined (two functions) so the contract is self-contained — no OpenZeppelin install needed, and it compiles in both the CLI and the webapp's in-app compiler.

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

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

The sender specifies a recipient per transfer. On approval, funds go to the transfer's `recipient`; on rejection, back to the sender. No `setRecipient` — each transfer carries its own. Same inlined `IERC20` interface as the single-payee variant.

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

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

Native USDC only exists on mainnet. On testnets, deploy this mintable 6-decimal ERC-20 first and use its address as the escrow's `_token` constructor arg. Open `mint` so you can fund sender wallets freely on testnet. Self-contained — no OpenZeppelin imports, so it compiles in both the CLI and the webapp's in-app compiler.

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract MockUSDC {
    string public name = "Mock USDC";
    string public symbol = "USDC";
    uint8 public constant decimals = 6;
    uint256 public totalSupply;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    /// @notice Open mint — testnet only.
    function mint(address to, uint256 amount) external {
        totalSupply += amount;
        balanceOf[to] += amount;
        emit Transfer(address(0), to, amount);
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        uint256 allowed = allowance[from][msg.sender];
        require(allowed >= amount, "insufficient allowance");
        if (allowed != type(uint256).max) {
            allowance[from][msg.sender] = allowed - amount;
        }
        _transfer(from, to, amount);
        return true;
    }

    function _transfer(address from, address to, uint256 amount) internal {
        require(balanceOf[from] >= amount, "insufficient balance");
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        emit Transfer(from, to, amount);
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

// OFAC/sanctions screening (separate Webacy endpoint)
// When enabled, sanctioned wallets are rejected immediately before the risk score check
export const SANCTIONS_CHECK_ENABLED = false;
```

### `src/lib/webacy.ts`

The screening client. GETs Webacy's address risk report and returns a normalized result; the task rejects any sender whose `overallRisk` is at or above `RISK_THRESHOLD`. When `SANCTIONS_CHECK_ENABLED` is true, it also checks the Webacy sanctions endpoint first — a sanctioned wallet is rejected immediately with no risk score evaluation.

```typescript
import { TaskContext } from "compose";
import { SANCTIONS_CHECK_ENABLED } from "./constants";

export type WalletScreeningResult = {
  address: string;
  riskScore: number | null;
  passed: boolean;
  sanctioned: boolean;
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

type WebacySanctionsResponse = {
  sanctioned: boolean;
};

const WEBACY_API_BASE = "https://api.webacy.com";

async function checkSanctions(
  address: string,
  apiKey: string,
  fetchFn: TaskContext["fetch"],
): Promise<boolean> {
  const data = await fetchFn<WebacySanctionsResponse>(
    `${WEBACY_API_BASE}/addresses/sanctioned/${address}`,
    { method: "GET", headers: { "x-api-key": apiKey } },
  );
  return data?.sanctioned ?? false;
}

export async function screenWallet(
  address: string,
  apiKey: string,
  riskThreshold: number,
  fetchFn: TaskContext["fetch"],
): Promise<WalletScreeningResult> {
  // --- Sanctions gate (hard reject, no threshold) ---
  if (SANCTIONS_CHECK_ENABLED) {
    const sanctioned = await checkSanctions(address, apiKey, fetchFn);
    if (sanctioned) {
      return {
        address,
        riskScore: null,
        passed: false,
        sanctioned: true,
        triggeredRules: ["OFAC/sanctions match"],
      };
    }
  }

  // --- Risk score check ---
  const url = `${WEBACY_API_BASE}/addresses/${address}?chain=base`;

  const data = await fetchFn<WebacyResponse>(url, {
    method: "GET",
    headers: { "x-api-key": apiKey },
  });

  if (!data) {
    throw new Error(`Webacy API returned empty response for ${address}`);
  }

  const riskScore = data.overallRisk ?? null;

  const triggeredRules: string[] = (data.issues ?? [])
    .flatMap((issue) => issue.tags ?? [])
    .filter((tag) => tag.severity >= 2)
    .map((tag) => tag.key);

  return {
    address,
    riskScore,
    passed: riskScore === null || riskScore < riskThreshold,
    sanctioned: false,
    triggeredRules,
  };
}
```

### `src/lib/mock-screener.ts` (mock mode only)

Use this instead of `webacy.ts` when the user chose mock mode. Same `WalletScreeningResult` interface, no API key needed.

```typescript
import { TaskContext } from "compose";
import { SANCTIONS_CHECK_ENABLED } from "./constants";

export type WalletScreeningResult = {
  address: string;
  riskScore: number | null;
  passed: boolean;
  sanctioned: boolean;
  triggeredRules: string[];
};

// Add addresses to this set to simulate flagged/risky wallets
const DENY_LIST = new Set<string>([
  "0x000000000000000000000000000000000000dead",
  // Add your test "risky" addresses here (lowercase)
]);

// Add addresses to simulate sanctioned wallets (only checked when SANCTIONS_CHECK_ENABLED)
const SANCTIONS_LIST = new Set<string>([
  "0x0000000000000000000000000000000000000bad",
  // Add your test "sanctioned" addresses here (lowercase)
]);

export async function screenWallet(
  address: string,
  _apiKey: string,
  riskThreshold: number,
  _fetchFn: TaskContext["fetch"],
): Promise<WalletScreeningResult> {
  if (SANCTIONS_CHECK_ENABLED && SANCTIONS_LIST.has(address.toLowerCase())) {
    return {
      address,
      riskScore: null,
      passed: false,
      sanctioned: true,
      triggeredRules: ["OFAC/sanctions match"],
    };
  }

  const isRisky = DENY_LIST.has(address.toLowerCase());

  return {
    address,
    riskScore: isRisky ? 85 : 5,
    passed: !isRisky,
    sanctioned: false,
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
  sanctioned: boolean;
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

  const wallet = await evm.wallet({ name: "compliance-oracle-wallet", sponsorGas: true });

  let txHash: string;
  let decision: "approved" | "rejected";
  let reason: string;

  if (screenResult.sanctioned) {
    decision = "rejected";
    reason = "Sender is on OFAC/sanctions list";

    log.warn(`rejecting transfer #${transferId} — sender ${sender} is sanctioned, returning ${formatUsdc(amount)}`);

    const result = await wallet.writeContract(
      evm.chains[CONFIG.chain],
      CONFIG.contractAddress,
      "rejectTransfer(uint256)",
      [id],
    );
    txHash = result.hash;
  } else if (screenResult.passed) {
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

  // Use the oracle wallet for read calls (address must match the contract's oracle)
  const wallet = await evm.wallet({ name: "compliance-oracle-wallet", sponsorGas: true });

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

> **The steps below are the Bash / local-CLI procedure. If a `deployComposeApp` tool is available (webapp chatbot), follow the in-app flow in Mode Detection above instead.**

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

The `goldsky` CLI and auth checks are the standard Compose preflight (see `/compose` and `/auth-setup`). If `goldsky compose --version` prints `compose CLI is not installed`, run `goldsky compose install` (idempotent on the stable channel), then re-check. Compliance-specific:

1. **Compose CLI version (check first).** `goldsky compose --version` must print `0.8.1` or newer, and `deployContract`/`writeContract` must be known commands — everything below (deploys, secrets, smoke test) depends on them. Run:
   ```bash
   goldsky compose --version          # expect: goldsky compose 0.8.1
   goldsky compose deployContract --help >/dev/null 2>&1 && echo "deployContract OK" || echo "deployContract UNKNOWN — CLI too old"
   ```
   If the version is older than `0.8.1` or either command is unknown, **offer** `goldsky compose update` (or `goldsky compose update 0.8.1` for a specific version), run it on confirmation, then re-check before proceeding.
2. **`cast`** — `cast --version`. Install with `curl -L https://foundry.paradigm.xyz | bash && foundryup` if missing. Used only for the `cast` alternative in Step 7 (`forge` is no longer required — `deployContract` compiles in-CLI).
3. **No OpenZeppelin install needed.** All contracts are self-contained — `IERC20` is inlined as a two-function interface in the escrow contract, and `MockUSDC` is a standalone ERC20 implementation. This means the contracts compile in both the CLI's `deployContract` and the webapp's in-app compiler without any `npm install`.

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
6. **"Do you want to enable OFAC/sanctions screening?"** *(Webacy only — skip for mock mode and bring-your-own.)* Webacy offers a separate sanctions endpoint that checks if a wallet appears on OFAC or other sanctions lists. This is a hard gate (sanctioned = instant reject, no threshold). Recommended for regulated or fintech use cases. Default `false`. Set `SANCTIONS_CHECK_ENABLED` in `src/lib/constants.ts`. Uses the same `WEBACY_API_KEY` — no extra credentials needed.
7. **Recipient (single-payee only)** — **"What address should approved payments be sent to?"** They can provide an address now, or use the oracle wallet address for testing (simplest — "I'll use the oracle wallet for now"). This can be changed later via `setRecipient()` on the contract. The recipient becomes the third constructor arg.

## Step 2 — Oracle wallet and contract deploy

The oracle is a named Compose smart wallet, `compliance-oracle-wallet`. Its address becomes the contract's `oracle`, and the Compose task signs callbacks through the same wallet at runtime (gas-sponsored). Create it first, capture its address, then deploy the contracts with that address as the `oracle` constructor arg. `goldsky compose deployContract` deploys through the gas-sponsored Compose wallet, so no funded EOA is needed for the deploy.

```bash
# Create the oracle smart wallet and capture its address
ORACLE_ADDRESS=$(goldsky compose wallet create compliance-oracle-wallet --json | jq -r .address)
```

In a fresh shell, list the wallet to recover the address (it must match the contract's `oracle` at runtime):

```bash
goldsky compose wallet list
# → copy the compliance-oracle-wallet address as $ORACLE_ADDRESS
```

**Base Sepolia (recommended): deploy a MockUSDC first**, then use its address as the escrow's `_token` arg. Both deploys go through the gas-sponsored Compose wallet (Base Sepolia is sponsored, so nothing needs funding). The `oracle` is the `compliance-oracle-wallet` address captured above. (Each `deployContract`/`writeContract` needs a project API key. Auth: export `GOLDSKY_API_TOKEN=<project API key>` once in the shell (preferred: keeps the key out of argv and shell history), or pass `-t "$GOLDSKY_PROJECT_KEY"` per command, or use an active `goldsky login` session. Precedence: `--token` > `GOLDSKY_API_TOKEN` > `~/.goldsky/auth_token`. Generate the key at **Settings > API Keys** in the Goldsky dashboard.)

```bash
# 1) MockUSDC - no constructor args (testnet only)
TOKEN_ADDRESS=$(goldsky compose deployContract contracts/MockUSDC.sol --chain-id $CHAIN_ID --json | jq -r .address)

# 2) ComplianceGatedTransfer - oracle is the compliance-oracle-wallet address;
#    constructor args depend on the payment model:

# Single-payee (3 args: token, oracle, recipient):
CONTRACT_ADDRESS=$(goldsky compose deployContract contracts/ComplianceGatedTransfer.sol \
  --chain-id $CHAIN_ID \
  --constructor-args $TOKEN_ADDRESS $ORACLE_ADDRESS $RECIPIENT_ADDRESS --json | jq -r .address)

# P2P (2 args: token, oracle):
CONTRACT_ADDRESS=$(goldsky compose deployContract contracts/ComplianceGatedTransfer.sol \
  --chain-id $CHAIN_ID \
  --constructor-args $TOKEN_ADDRESS $ORACLE_ADDRESS --json | jq -r .address)
```
`--json` suppresses ascii art; on failure the command exits 1 with `{"error":true,"code":"...","message":"..."}` on stderr, so an empty capture means check stderr.

Use the chain ID for the user's chosen chain (e.g. `84532` for Base Sepolia, `8453` for Base mainnet, `11155111` for Ethereum Sepolia, etc.).

The ABI for each contract is auto-saved to `src/contracts/<Name>.json`. Once both deploys print `Address:`, generate the typed contract classes (required before any typecheck — the `tsconfig.json` `paths` entry points at `.compose/types.d.ts`, which codegen produces):

```bash
goldsky compose codegen
```

> **TypeScript pin:** the inlined `tsconfig.json` typechecks on **TypeScript 5.x**; TS 6 rejects `baseUrl`. If you run a typecheck, pin `npx -y typescript@5 tsc` rather than a bare `tsc`.

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

## Step 4 — Optional: publish to a new GitHub repo

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

(The `.gitignore` from Step 0b excludes `.env`; the grep is a backstop. On the default keyless path there is no oracle key to leak; on the Advanced BYO-key path above, never commit `ORACLE_PRIVATE_KEY` or any private key.)

## Step 5 — Set your secret (before deploy)

**Webacy mode only** — mock mode and bring-your-own need no `WEBACY_API_KEY` (make sure it's removed from `compose.yaml`'s `secrets` array, per Step 1) and skip this step. The running task uses `WEBACY_API_KEY` to screen sender wallets via the Webacy AML API. If you haven't already, sign up at https://developers.webacy.co/ and create an API key. (The whole flow was verified working with a stub key set here before deploy, so a placeholder is fine right up to the smoke test.)

- **CLI:** set the secret BEFORE `goldsky compose deploy` (Step 6). The user must run this command themselves (the agent should never capture or echo back the key value). **Always include `-n $APP_NAME`** when showing this command to the user — the user may not be in the app directory:
  ```bash
  goldsky compose secret set WEBACY_API_KEY --value "$WEBACY_API_KEY" -n $APP_NAME
  ```
  The user exports the value in their own shell (or writes it into a chmod-600 `.env` and `source`s it) — never paste it into the chat or echo it back. `compose deploy` validates that every manifest-declared secret exists and bakes it into the pod at deploy time, so an unset secret 400s the deploy with "The following secrets referenced in the manifest do not exist". Secrets are not hot-reloaded: setting or updating a secret after deploy only writes to storage and does NOT reach the running pod without a redeploy. For the after-deploy case, `goldsky compose secret set WEBACY_API_KEY --value "$WEBACY_API_KEY" --redeploy` sets the secret and triggers a redeploy in one step.
- **In-app (chatbot):** the in-app deploy skips secret validation, so `deployComposeApp` (Step 6) succeeds without it. After deploy, add `WEBACY_API_KEY` in the Compose app's dashboard under the app's **Secrets** page, then **redeploy from the dashboard** so the pod picks it up. The app does not start working on set alone; the redeploy is required. NEVER attempt to set a secret from chat; there is no tool, by design.

## Step 6 — Deploy to Goldsky

```bash
goldsky compose deploy
```

First deploy may take 1-2 minutes. Watch for `Deployed compose app: <the chosen app name>` (e.g. `compliance-oracle`). The `on_transfer_requested` event listener and the `reconcile` cron both go live.

**⚠ MANDATORY: After deploy succeeds, always proceed directly to Step 7 (smoke test).** Do not stop at "deployed" or only mention secrets — the user needs to see their oracle actually process a transfer end-to-end. If the user is in the webapp (no Bash tool), check whether they have the Goldsky CLI installed and walk them through installing it (`curl https://goldsky.com | sh && goldsky compose install && goldsky login`) before giving the smoke test commands.

## Step 7 — Smoke test

This step runs **after** `compose deploy` (Step 6), so the app's wallets now exist. **Always walk the user through this step** — do not skip it or wait for them to ask. The flow differs depending on whether you deployed with MockUSDC (testnet) or real USDC (mainnet).

**First, get the app's default wallet address** — this is the sender for the smoke test. **Always pass `-n $APP_NAME`** (the app name from Step 1, e.g. `compliance-oracle`) on every `wallet` and `writeContract` command. Without `-n`, the CLI tries to find `compose.yaml` in the current directory — which fails if the user isn't in the app directory (always the case for webapp users, and often for CLI users who navigated away).

```bash
# create (or fetch) the wallet the writeContract calls will send from, and print its address
COMPOSE_WALLET=$(goldsky compose wallet create default -n $APP_NAME --json | jq -r .address)
```
(`POST /:appName/wallets` provisions the hosted Postgres and creates or resolves the wallet on demand, so this works before or after the app deploy.)

Each `writeContract` below needs `-t <project API key>` or an active `goldsky login` session. Auth: export `GOLDSKY_API_TOKEN=<project API key>` once in the shell (preferred), or pass `-t "$GOLDSKY_PROJECT_KEY"` per command. Precedence: `--token` > `GOLDSKY_API_TOKEN` > `~/.goldsky/auth_token`.

### MockUSDC flow (testnet — recommended for first test)

MockUSDC has an open `mint()` function, so `writeContract` can create test tokens out of thin air. No funding needed — everything is gas-sponsored.

```bash
# 1) Mint 1.00 mUSDC to the app wallet
goldsky compose writeContract -n $APP_NAME --chain-id $CHAIN_ID --to $TOKEN_ADDRESS \
  --function "mint(address,uint256)" --args $COMPOSE_WALLET 1000000

# 2) Approve the escrow contract to pull the app wallet's USDC
goldsky compose writeContract -n $APP_NAME --chain-id $CHAIN_ID --to $TOKEN_ADDRESS \
  --function "approve(address,uint256)" --args $CONTRACT_ADDRESS 1000000

# 3) Request a 1.00 USDC transfer — emits TransferRequested, triggering the oracle
goldsky compose writeContract -n $APP_NAME --chain-id $CHAIN_ID --to $CONTRACT_ADDRESS \
  --function "requestTransfer(uint256)" --args 1000000
```

> **Why this works without the oracle wallet:** `MockUSDC.mint` is open; both `approve` and `requestTransfer` are sent from the same app wallet, and `requestTransfer` pulls via `transferFrom` from `msg.sender` — so the sender does not need to be the oracle. The oracle wallet only signs the `approveTransfer`/`rejectTransfer` callback at runtime.

### Real USDC flow (mainnet)

You can't mint real USDC — you need to fund the app wallet first.

1. **Send real USDC to `$COMPOSE_WALLET`** from any external wallet (MetaMask, Coinbase, exchange withdrawal, etc.). Even a small amount like 1.00 USDC is enough for testing.
2. Once the USDC arrives at `$COMPOSE_WALLET`, run the approve + requestTransfer:

```bash
# 1) Approve the escrow contract to pull USDC from the app wallet
goldsky compose writeContract -n $APP_NAME --chain-id $CHAIN_ID --to $TOKEN_ADDRESS \
  --function "approve(address,uint256)" --args $CONTRACT_ADDRESS 1000000

# 2) Request a 1.00 USDC transfer — emits TransferRequested, triggering the oracle
goldsky compose writeContract -n $APP_NAME --chain-id $CHAIN_ID --to $CONTRACT_ADDRESS \
  --function "requestTransfer(uint256)" --args 1000000
```

> **No mint step** — skip straight to approve. The USDC is already in the wallet from your external transfer. Gas is still sponsored on Base.

### Verifying the result

**Stream** the logs and watch the decision land (bare `goldsky compose logs` is a one-shot dump; add `-f`/`--follow` to watch the next fire):

```bash
goldsky compose logs -f
```

Better, foundry-free checks (run alongside or instead of `logs -f`):

```bash
goldsky compose runs --task on_transfer_requested --since 5m --json
goldsky compose collections query transfer-audits
```

**What to look for:** `deposit received`, `screening complete ... risk score N`, then `transfer #<id> APPROVED` (or a reject warning) with an `oracleTxHash`. Verify on-chain — `transfers(<id>)` status should be `1` (Approved) or `2` (Rejected), not `0`:

```bash
cast call $CONTRACT_ADDRESS "transfers(uint256)(address,uint256,uint8)" <id> --rpc-url $RPC_URL
```

### Alternative — `cast` from your own funded EOA

If you'd rather drive the flow with a separate sender key (`$SENDER_KEY`, not the oracle), it is **not** gas-sponsored, so fund it first: get Base Sepolia ETH from a faucet (e.g. https://www.coinbase.com/faucets/base-sepolia) into `$SENDER_ADDRESS`, then:

```bash
# mint is open — any funded key mints to the sender (MockUSDC only)
cast send $TOKEN_ADDRESS "mint(address,uint256)" $SENDER_ADDRESS 1000000 \
  --rpc-url $RPC_URL --private-key $SENDER_KEY   # 1.00 mUSDC
# approve the escrow, then request (ERC-20 needs prior approval)
cast send $TOKEN_ADDRESS "approve(address,uint256)" $CONTRACT_ADDRESS 1000000 \
  --rpc-url $RPC_URL --private-key $SENDER_KEY
cast send $CONTRACT_ADDRESS "requestTransfer(uint256)" 1000000 \
  --rpc-url $RPC_URL --private-key $SENDER_KEY
```

Generate `$SENDER_KEY` without printing it (a separate funded EOA, not the oracle wallet): `cast wallet new --json > /tmp/s.json; SENDER_KEY=$(jq -r '.[0].private_key' /tmp/s.json); SENDER_ADDRESS=$(cast wallet address "$SENDER_KEY"); echo "$SENDER_ADDRESS"; shred -u /tmp/s.json`.

## Troubleshooting

- **`error: Unknown command "deployContract". Did you mean command "deploy"?` (or the `writeContract` variant).** Compose CLI is older than 0.8.1. Run `goldsky compose update` (or `goldsky compose update 0.8.1`), confirm `goldsky compose --version` prints `0.8.1`+, then retry.
- **Edits to `compose.yaml` or source files don't take effect after redeploy.** Stale `.compose/` bundle cache. Run `rm -rf .compose/` and redeploy.
- **`approveTransfer`/`rejectTransfer` reverts with `not oracle`.** The `compliance-oracle-wallet` address doesn't match the contract's `oracle`. They must be the same wallet. Check: `cast call $CONTRACT_ADDRESS "oracle()(address)" --rpc-url $RPC_URL` should equal the `compliance-oracle-wallet` address (from `goldsky compose wallet list`).
- **`requestTransfer` reverts with "transfer amount exceeds allowance".** The sender didn't `approve` the escrow to spend their USDC first. Run the `approve` call before `requestTransfer`.
- **Task never fires when a transfer is requested.** Confirm `compose.yaml`'s `contract:` and `network:` match where you deployed, the deploy succeeded, and the trigger is active (`goldsky compose status`). Wiring only one of `chain` (constants.ts) / `network` (compose.yaml) is the usual cause.
- **Webacy returns an empty response / task throws.** Check `WEBACY_API_KEY` is set as a secret and valid, and the address is well-formed hex. Transient failures are absorbed by the `retry_config` (3 attempts, backoff).
- **Reject scenario approves instead.** On Base Sepolia, a fresh test wallet has no on-chain history, so Webacy scores it low (it passes). Use a known-flagged address, or test the reject path on mainnet where real risk data exists.
- **Deploy fails with `No Alchemy bundler URL for chain <id>`.** The chosen chain is outside the cloud deploy path's bundler coverage (Ethereum, Sepolia, Polygon, Polygon Amoy, Arbitrum, Arbitrum Sepolia, Optimism, Optimism Sepolia, Base, Base Sepolia). Pick a covered chain or deploy that contract with your own funded EOA. Funding the Compose wallet does not help, the deploy is a sponsored UserOp, not an EOA transaction. Broader provider coverage is FOU-991.
- **Re-running `deployContract` with identical contract + args + app is refused ("This contract has already been deployed with this app...").** This is a CREATE2 pre-tx refusal - it prints **no** `Deploy Block:`. The address is deterministic from contract code + constructor args + app name + project, so an identical combination reproduces the same address. Fresh-deploy levers: change a constructor arg, change the source, or use a different app name. The new name must not differ only by case or by `-`/`_`: names canonicalize (lowercase, `[-_]+` -> `-`), so `my-app`, `My_App`, and `my__app` collide and the deploy returns 409. For the no-arg `MockUSDC` the **only** lever is the app name; for `ComplianceGatedTransfer` (takes `(token, oracle)` or `(token, oracle, recipient)`) changing a constructor arg also works. ⚠ Renaming the app changes **all** future deploy addresses and conflicts with the `compose deploy` app name, so prefer the constructor-arg lever where possible - for no-arg contracts the app-name lever is the only option.

## What you should NOT do

- Do not point the app at the mainnet demo contract `0x39efE8A851A4Da22fa40828F6D4b3DC6b54545Aa` (or any contract you didn't deploy). Its `oracle` is a fixed key you don't hold, so every callback reverts `not oracle`. Deploy your own.
- Do not use a different address for the contract's `oracle` constructor arg than the `compliance-oracle-wallet` address. They must be the same wallet.
- Do not import `viem`, `ethers`, or any external package inside the Compose task code — use `evm.decodeEventLog`, `evm.wallet`, and `evm.chains` from the context.
- Do not deploy the gated-transfer contract to Base mainnet with real USDC as a first test — start on Base Sepolia with MockUSDC.

## Related

- **`/compose`** — Build a new/custom Compose app from scratch, or explain what Compose is.
- **`/compose-reference`** — Manifest, CLI, TaskContext API, wallets, gas sponsorship, codegen.
- **`/compose-doctor`** — Diagnose and fix a broken Compose app.
- **`/auth-setup`** — `goldsky login` walkthrough.
