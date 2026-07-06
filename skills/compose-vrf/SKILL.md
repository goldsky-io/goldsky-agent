---
name: compose-vrf
description: "Build and deploy the Goldsky Compose VRF (verifiable random function) example under the user's own account — a Compose app that listens for a `RandomnessRequested` event on an EVM contract, fetches verifiable randomness from the drand beacon, and writes it back on-chain via `fulfillRandomness` with the drand round + BLS signature so anyone can verify it. Triggers on: 'build a VRF', 'verifiable random function', 'onchain randomness', 'provably fair random numbers', 'drand oracle', 'random number generator onchain', 'set up / deploy the VRF example', 'compose vrf'. Recommends the shared, fully-unpermissioned RandomnessConsumer on Base Sepolia so there's nothing to deploy. This skill carries the complete app source (manifest, contract, ABI, tasks, drand lib) so the assistant can deploy it off the shelf or customize it. For a custom/novel Compose app that isn't this VRF, use /compose. For debugging an already-deployed app, use /compose-doctor. For manifest/CLI/API field lookups, use /compose-reference."
---

# Build: Compose VRF

Stand up the VRF example under the user's own Goldsky account. The app listens for a `RandomnessRequested(uint256,address)` event on an EVM contract, fetches verifiable randomness from the **drand** beacon (BLS12-381 threshold signatures, verifiable by anyone), and writes it back on-chain via `fulfillRandomness(requestId, randomness, round, signature)`. Trust comes from the stored drand `round` + `signature`, not from the caller, so the shared example contract is safe to leave open.

This template supplies only what's specific to the VRF app — how it works and its **full source** (below). The recommended path uses a **shared, fully-unpermissioned `RandomnessConsumer` on Base Sepolia** at `0x6273AB73C95Ba2233281F1eb8aa3b21D9352AD6d`, so the user deploys nothing and the Compose smart wallet is auto-created and gas-sponsored.

## Step 0 — Load the base skills first

**Before anything else — before you answer, ask a question, scaffold a file, or call `deployComposeApp` — load the two base skills this template depends on:**

1. **`Skill(compose)`** — the always-on Compose guide: the golden rules (never assume anything about the app on the user's behalf; ask when unsure) and general build guidance.
2. **`Skill(compose-reference)`** — the manifest / field / API reference; consult before writing any `compose.yaml` or task file.

This template deliberately omits those rules and that reference — they are **required** to build correctly and are not repeated here. Do not proceed until both are loaded.

## Mode Detection

Pick the mode from the tools available to you:

- **A `deployComposeApp` tool is available (Goldsky webapp chatbot) — this is the preferred in-app flow.** Do NOT emit `goldsky` terminal commands or `cliCommand` cards, and do NOT use Step 0 / `degit` / `forge` / `goldsky compose deploy`. Instead: give a 2-3 sentence plain explanation, then ask the **single** config question below with `askUser` (tag the recommended option with `recommendedIndex`). **Do NOT ask the user what to name the app** — name it `vrf-app` automatically; they can rename it after it's deployed. Ask only:
  - **Contract** — ask this explicitly, do not assume: *"Do you have your own `RandomnessConsumer`-style contract, or should we use a shared demo contract on Base Sepolia to get running quickly?"* Options: **"Use the shared demo contract on Base Sepolia (recommended — nothing to deploy)"** and **"I'll use my own contract."** On the shared path, `CONTRACT_ADDRESS` is the **HARDCODED** address `0x6273AB73C95Ba2233281F1eb8aa3b21D9352AD6d` on `baseSepolia` — copy it character-for-character, do NOT alter or retype it from memory; mention in prose that it's demos-only, not production. On the own path, ask the user to paste their contract address and chain (their contract must emit `RandomnessRequested(uint256,address)` and accept `fulfillRandomness`), and use exactly what they paste.

  The Compose smart wallet is auto-created at runtime and gas-sponsored on Base Sepolia — never tell the user to create or fund a wallet. On the shared path there is **no fulfiller to set** (the contract is permissionless), so the wallet just works. After the single question, scaffold these files in-memory from **The app (full source)** below and pass them to `deployComposeApp` (do NOT degit): `compose.yaml`, `src/contracts/RandomnessConsumer.json` (verbatim ABI, required for codegen), `src/lib/drand.ts`, and the three task files. Set the top-level `name:` to `vrf-app`; set `CONTRACT_ADDRESS` in both task files and the `contract:` field in `compose.yaml` to the shared address (or the user's, on the own path), and the `evm.chains.*` reference + trigger `network:` to the chosen chain. Follow `/compose-reference` for the manifest shape and the sandbox import rule before emitting the files (per the golden rules in `/compose` — don't synthesize the manifest from memory). Then **call `deployComposeApp` in the SAME turn**; don't ask the user to confirm first or emit any `goldsky` command. **In this mode, ignore Steps 0–8 below** — they are the CLI/local procedure.
- **`Bash` is available (local CLI / coding agent):** execute the steps below directly, parsing output into later commands.
- **Neither (pure reference Q&A):** explain what the app does; for step-by-step help point them at `npx skills add goldsky-io/goldsky-agent` to run it locally with Bash.

## Non-negotiables

- **The shared contract at `0x6273AB73C95Ba2233281F1eb8aa3b21D9352AD6d` on Base Sepolia is fully unpermissioned — anyone can call `fulfillRandomness`.** That is safe here: the randomness is only trusted because of the drand `round` + BLS `signature` stored on-chain, which anyone can verify off-chain against the drand quicknet public key. It exists for getting started and demos only. Tell the user, in prose, that it must NOT be used in production, and it only exists on Base Sepolia.
- **Do NOT point the app at `0x53...` or `0xE05Ceb3E269029E3bab46E35515e8987060D1027`.** That older demo contract is **permissioned** (its `fulfiller` is a fixed address, not the user's Compose wallet), so every off-the-shelf `fulfillRandomness` reverts with `OnlyFulfiller`. The shared no-deploy contract is `0x6273AB...` and nothing else.
- **Three places share the contract address:** the `contract:` field in `compose.yaml`, and `CONTRACT_ADDRESS` in both `src/tasks/fulfill-randomness.ts` and `src/tasks/request-randomness.ts`. If the user changes it, change all three.
- **Deploy-your-own path only:** the drand fulfillment is permissionless in the reference contract, but if the user's own contract restricts fulfillment, the authorized fulfiller must be the Compose wallet or every `fulfillRandomness` reverts. On the shared contract there is no such restriction.
- **Never run `forge create`, `goldsky compose deploy`, `git push`, or `gh repo create` without showing the exact command first and getting explicit confirmation.**

## The app (full source)

This is the complete VRF app. In the in-app flow, scaffold these files in-memory verbatim and set the address/chain per the interview. In the CLI flow, Step 0 pulls the same files from `goldsky-io/documentation-examples`; only edit them if you're customizing. The shared no-deploy contract is baked in as the `CONTRACT_ADDRESS` default below.

### `compose.yaml`

```yaml
name: "vrf-app"
api_version: "stable"

tasks:
  # Utility task to get the Compose wallet address (only needed if deploying your own contract)
  - path: "./src/tasks/generate-wallet.ts"
    name: "generate_wallet"
    triggers:
      - type: "http"
        authentication: "auth_token"

  # HTTP endpoint to request randomness (no MetaMask needed)
  - path: "./src/tasks/request-randomness.ts"
    name: "request_randomness"
    triggers:
      - type: "http"
        authentication: "auth_token"

  # Main fulfillment task — triggered by the on-chain RandomnessRequested event
  - path: "./src/tasks/fulfill-randomness.ts"
    name: "fulfill_randomness"
    triggers:
      - type: "onchain_event"
        network: "base_sepolia"
        # Shared, fully-unpermissioned RandomnessConsumer (anyone can fulfill) — nothing to deploy.
        # Keep in sync with CONTRACT_ADDRESS in the two task files.
        contract: "0x6273AB73C95Ba2233281F1eb8aa3b21D9352AD6d"
        events:
          - "RandomnessRequested(uint256,address)"
    retry_config:
      max_attempts: 3
      initial_interval_ms: 1000
      backoff_factor: 2
```

### `src/tasks/fulfill-randomness.ts`

```typescript
import { TaskContext, OnchainEvent } from "compose";

import {
  fetchLatestRandomness,
  toBytes32,
  toBytes,
  DRAND_CHAIN_INFO,
} from "../lib/drand.ts";

// Shared, fully-unpermissioned RandomnessConsumer on Base Sepolia — anyone can
// fulfill, so there's nothing to deploy and no wallet to whitelist. Swap for
// your own contract to go to production. Keep in sync with the CONTRACT_ADDRESS
// in request-randomness.ts and the `contract:` field in compose.yaml.
const CONTRACT_ADDRESS = "0x6273AB73C95Ba2233281F1eb8aa3b21D9352AD6d";

/**
 * Fulfill randomness requests using drand.
 *
 * Triggered by the on-chain RandomnessRequested event (configured in compose.yaml).
 * Fetches verifiable randomness from drand and writes it back to the target contract.
 */
export async function main(context: TaskContext, event?: OnchainEvent) {
  const { fetch, evm } = context;

  // Parse request ID from event topics
  const requestId = event?.topics[1] ? BigInt(event.topics[1]) : 0n;

  // Fetch randomness from drand
  const drandResponse = await fetchLatestRandomness(fetch);

  console.log(`fetched drand round ${drandResponse.round}`);

  // Get wallet and instantiate typed contract (generated from src/contracts/RandomnessConsumer.json)
  const wallet = await evm.wallet({
    name: "randomness-fulfiller",
  });

  const contract = new evm.contracts.RandomnessConsumer(
    CONTRACT_ADDRESS,
    evm.chains.baseSepolia,
    wallet
  );

  // Prepare the fulfillment arguments
  const randomnessBytes32 = toBytes32(drandResponse.randomness);
  const signatureBytes = toBytes(drandResponse.signature);

  // Fulfill the randomness request on-chain
  const { hash } = await contract.fulfillRandomness(
    requestId.toString(),
    randomnessBytes32,
    drandResponse.round,
    signatureBytes
  );

  console.log(`fulfilled request ${requestId} in tx ${hash}`);

  return {
    success: true,
    requestId: requestId.toString(),
    transactionHash: hash,
    drand: {
      round: String(drandResponse.round),
      randomness: randomnessBytes32,
      chainHash: DRAND_CHAIN_INFO.hash,
    },
  };
}
```

### `src/tasks/request-randomness.ts`

```typescript
import { TaskContext } from "compose";

// Shared, fully-unpermissioned RandomnessConsumer on Base Sepolia — anyone can
// request. Keep in sync with the CONTRACT_ADDRESS in fulfill-randomness.ts and
// the `contract:` field in compose.yaml.
const CONTRACT_ADDRESS = "0x6273AB73C95Ba2233281F1eb8aa3b21D9352AD6d";

export async function main(context: TaskContext): Promise<{
  requestId: string;
  txHash: string;
}> {
  const { evm } = context;

  const wallet = await evm.wallet({
    name: "randomness-requester",
  });

  // Instantiate typed contract (generated from src/contracts/RandomnessConsumer.json)
  const contract = new evm.contracts.RandomnessConsumer(
    CONTRACT_ADDRESS,
    evm.chains.baseSepolia,
    wallet
  );

  // Send the request transaction
  const { hash } = await contract.requestRandomness();

  // Read nextRequestId after tx — subtract 1 to get our requestId
  const nextId = await contract.nextRequestId();
  const requestId = String(BigInt(nextId) - 1n);

  return {
    requestId,
    txHash: hash,
  };
}
```

### `src/tasks/generate-wallet.ts`

```typescript
import { TaskContext } from "compose";

/**
 * Generate the Compose wallet and output its address.
 *
 * Only needed on the deploy-your-own path: run this before deploying your
 * contract to get the fulfiller address to authorize.
 *   goldsky compose callTask generate_wallet '{}'
 */
export async function main(context: TaskContext) {
  const { evm } = context;

  const wallet = await evm.wallet({ name: "randomness-fulfiller" });

  return {
    address: wallet.address,
    name: wallet.name,
    message: "Use this address as the fulfiller when deploying your contract",
  };
}
```

### `src/lib/drand.ts`

```typescript
/**
 * drand API utilities for fetching verifiable randomness.
 *
 * drand produces BLS12-381 threshold signatures that anyone can verify.
 * The randomness is sha256(signature), making it deterministic and verifiable.
 */

// ============ Types ============

export type DrandResponse = {
  round: number;
  randomness: string; // hex - sha256(signature)
  signature: string; // hex - BLS12-381 signature (96 bytes)
  previous_signature: string;
};

export type DrandChainInfo = {
  hash: string;
  publicKey: string;
  genesisTime: number;
  period: number;
};

// ============ Constants ============

/**
 * drand quicknet chain info (3 second rounds).
 * Use these values to verify randomness off-chain.
 *
 * Note: Quicknet uses "unchained" randomness (no previous_signature linking)
 * and BLS signatures on G1 curve instead of G2.
 */
export const DRAND_CHAIN_INFO: DrandChainInfo = {
  hash: "52db9ba70e0cc0f6eaf7803dd07447a1f5477735fd3f661792ba94600c84e971",
  publicKey:
    "83cf0f2896adee7eb8b5f01fcad3912212c437e0073e911fb90022d3e760183c8c4b450b6a0a6c3ac6a5776a2d1064510d1fec758c921cc22b0e17e63aaf4bcb5ed66304de9cf809bd274ca73bab4af5a6e9c76a4bc09e76eae8991ef5ece45a",
  genesisTime: 1692803367,
  period: 3, // seconds between rounds
};

export const DRAND_API_URL =
  "https://api.drand.sh/52db9ba70e0cc0f6eaf7803dd07447a1f5477735fd3f661792ba94600c84e971";

// ============ Functions ============

/**
 * Fetch the latest randomness from drand.
 */
export async function fetchLatestRandomness(
  fetchFn: <T>(url: string) => Promise<T | undefined>
): Promise<DrandResponse> {
  const response = await fetchFn<DrandResponse>(
    `${DRAND_API_URL}/public/latest`
  );

  if (!response) {
    throw new Error("Failed to fetch randomness from drand");
  }

  return response;
}

/**
 * Fetch randomness for a specific round.
 */
export async function fetchRandomnessForRound(
  fetchFn: <T>(url: string) => Promise<T | undefined>,
  round: number
): Promise<DrandResponse> {
  const response = await fetchFn<DrandResponse>(
    `${DRAND_API_URL}/public/${round}`
  );

  if (!response) {
    throw new Error(`Failed to fetch randomness for round ${round}`);
  }

  return response;
}

/**
 * Convert hex string to bytes32 format (with 0x prefix, 64 chars).
 */
export function toBytes32(hex: string): `0x${string}` {
  // Remove 0x prefix if present
  const clean = hex.startsWith("0x") ? hex.slice(2) : hex;
  // Pad to 64 characters (32 bytes)
  const padded = clean.padStart(64, "0");
  return `0x${padded}` as `0x${string}`;
}

/**
 * Convert hex string to bytes (with 0x prefix).
 */
export function toBytes(hex: string): `0x${string}` {
  const clean = hex.startsWith("0x") ? hex : `0x${hex}`;
  return clean as `0x${string}`;
}
```

### `src/contracts/RandomnessConsumer.json` (ABI — required for codegen)

Write this verbatim; contract codegen reads it to build `evm.contracts.RandomnessConsumer`. Never invent the ABI.

```json
[
  { "type": "constructor", "inputs": [{ "name": "_fulfiller", "type": "address", "internalType": "address" }], "stateMutability": "nonpayable" },
  { "type": "function", "name": "fulfillRandomness", "inputs": [{ "name": "requestId", "type": "uint256", "internalType": "uint256" }, { "name": "randomness", "type": "bytes32", "internalType": "bytes32" }, { "name": "round", "type": "uint64", "internalType": "uint64" }, { "name": "signature", "type": "bytes", "internalType": "bytes" }], "outputs": [], "stateMutability": "nonpayable" },
  { "type": "function", "name": "fulfiller", "inputs": [], "outputs": [{ "name": "", "type": "address", "internalType": "address" }], "stateMutability": "view" },
  { "type": "function", "name": "getRandomness", "inputs": [{ "name": "requestId", "type": "uint256", "internalType": "uint256" }], "outputs": [{ "name": "randomness", "type": "bytes32", "internalType": "bytes32" }, { "name": "round", "type": "uint64", "internalType": "uint64" }, { "name": "signature", "type": "bytes", "internalType": "bytes" }], "stateMutability": "view" },
  { "type": "function", "name": "isFulfilled", "inputs": [{ "name": "requestId", "type": "uint256", "internalType": "uint256" }], "outputs": [{ "name": "", "type": "bool", "internalType": "bool" }], "stateMutability": "view" },
  { "type": "function", "name": "nextRequestId", "inputs": [], "outputs": [{ "name": "", "type": "uint256", "internalType": "uint256" }], "stateMutability": "view" },
  { "type": "function", "name": "requestRandomness", "inputs": [], "outputs": [{ "name": "requestId", "type": "uint256", "internalType": "uint256" }], "stateMutability": "nonpayable" },
  { "type": "function", "name": "requests", "inputs": [{ "name": "", "type": "uint256", "internalType": "uint256" }], "outputs": [{ "name": "requester", "type": "address", "internalType": "address" }, { "name": "fulfilled", "type": "bool", "internalType": "bool" }, { "name": "randomness", "type": "bytes32", "internalType": "bytes32" }, { "name": "round", "type": "uint64", "internalType": "uint64" }, { "name": "signature", "type": "bytes", "internalType": "bytes" }], "stateMutability": "view" },
  { "type": "function", "name": "setFulfiller", "inputs": [{ "name": "_fulfiller", "type": "address", "internalType": "address" }], "outputs": [], "stateMutability": "nonpayable" },
  { "type": "event", "name": "RandomnessFulfilled", "inputs": [{ "name": "requestId", "type": "uint256", "indexed": true, "internalType": "uint256" }, { "name": "randomness", "type": "bytes32", "indexed": false, "internalType": "bytes32" }, { "name": "round", "type": "uint64", "indexed": false, "internalType": "uint64" }, { "name": "signature", "type": "bytes", "indexed": false, "internalType": "bytes" }], "anonymous": false },
  { "type": "event", "name": "RandomnessRequested", "inputs": [{ "name": "requestId", "type": "uint256", "indexed": true, "internalType": "uint256" }, { "name": "requester", "type": "address", "indexed": true, "internalType": "address" }], "anonymous": false },
  { "type": "error", "name": "AlreadyFulfilled", "inputs": [] },
  { "type": "error", "name": "OnlyFulfiller", "inputs": [] },
  { "type": "error", "name": "RequestNotFound", "inputs": [] }
]
```

### `tsconfig.json`

```json
{
  "compilerOptions": {
    "target": "ES2020",
    "lib": ["ES2020", "dom"],
    "module": "esnext",
    "moduleResolution": "bundler",
    "esModuleInterop": true,
    "skipLibCheck": true,
    "strict": true,
    "resolveJsonModule": true,
    "baseUrl": ".",
    "paths": {
      "compose": [".compose/types.d.ts"]
    }
  },
  "include": ["src/**/*"]
}
```

### `contracts/RandomnessConsumer.sol` (only for the deploy-your-own path)

The reference contract. Fulfillment is permissionless by design — see the NatSpec on `fulfillRandomness`. The `fulfiller` field is an informational deploy-time label, not a gate.

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title RandomnessConsumer
 * @notice Example contract demonstrating the drand randomness request/fulfill pattern.
 * @dev Users can replace this with their own contract — just emit an event and implement fulfillment.
 *
 * Verification: the randomness is verifiable using drand's BLS12-381 signatures.
 * Chain info for verification (drand quicknet):
 *   - Chain Hash: 52db9ba70e0cc0f6eaf7803dd07447a1f5477735fd3f661792ba94600c84e971
 *   - Public Key: 83cf0f2896adee7eb8b5f01fcad3912212c437e0073e911fb90022d3e760183c8c4b450b6a0a6c3ac6a5776a2d1064510d1fec758c921cc22b0e17e63aaf4bcb5ed66304de9cf809bd274ca73bab4af5a6e9c76a4bc09e76eae8991ef5ece45a
 */
contract RandomnessConsumer {
    struct RandomnessRequest {
        address requester;
        bool fulfilled;
        bytes32 randomness;
        uint64 round;
        bytes signature;
    }

    /// @notice The Compose wallet recorded at deploy time (informational label only).
    address public fulfiller;

    /// @notice Counter for generating request IDs.
    uint256 public nextRequestId;

    /// @notice Mapping of request ID to request data.
    mapping(uint256 => RandomnessRequest) public requests;

    /// @notice Emitted when randomness is requested — Compose listens for this.
    event RandomnessRequested(uint256 indexed requestId, address indexed requester);

    /// @notice Emitted when randomness is fulfilled with full proof data.
    event RandomnessFulfilled(uint256 indexed requestId, bytes32 randomness, uint64 round, bytes signature);

    error OnlyFulfiller();
    error RequestNotFound();
    error AlreadyFulfilled();

    /// @param _fulfiller The Compose wallet address recorded as the deploy-time fulfiller label.
    constructor(address _fulfiller) {
        fulfiller = _fulfiller;
    }

    /**
     * @notice Request randomness — emits the event that Compose listens to.
     * @return requestId The ID of this request.
     */
    function requestRandomness() external returns (uint256 requestId) {
        requestId = nextRequestId++;

        requests[requestId] = RandomnessRequest({
            requester: msg.sender,
            fulfilled: false,
            randomness: bytes32(0),
            round: 0,
            signature: ""
        });

        emit RandomnessRequested(requestId, msg.sender);
    }

    /**
     * @notice Fulfill a randomness request with drand proof data.
     * @dev Permissionless: any caller may fulfill so the shared example contract is
     *      reusable by anyone without being whitelisted. Trust does not come from the
     *      caller's identity, it comes from the stored drand `round` + `signature`,
     *      which anyone can verify off-chain against the drand quicknet BLS public key.
     */
    function fulfillRandomness(
        uint256 requestId,
        bytes32 randomness,
        uint64 round,
        bytes calldata signature
    ) external {
        RandomnessRequest storage request = requests[requestId];
        if (request.requester == address(0)) revert RequestNotFound();
        if (request.fulfilled) revert AlreadyFulfilled();

        request.fulfilled = true;
        request.randomness = randomness;
        request.round = round;
        request.signature = signature;

        emit RandomnessFulfilled(requestId, randomness, round, signature);
    }

    function getRandomness(uint256 requestId)
        external
        view
        returns (bytes32 randomness, uint64 round, bytes memory signature)
    {
        RandomnessRequest storage request = requests[requestId];
        return (request.randomness, request.round, request.signature);
    }

    function isFulfilled(uint256 requestId) external view returns (bool) {
        return requests[requestId].fulfilled;
    }

    /// @notice Update the fulfiller label (for key rotation); does not gate fulfillment.
    function setFulfiller(address _fulfiller) external {
        if (msg.sender != fulfiller) revert OnlyFulfiller();
        fulfiller = _fulfiller;
    }
}
```

---

> **Steps 0–8 below are the Bash / local-CLI procedure. If a `deployComposeApp` tool is available (webapp chatbot), do NOT follow them — use the deploy-tool flow in Mode Detection above.**

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

If the user already cloned the example, skip this step and `cd` into it. Either way, set the `CONTRACT_ADDRESS` in both task files and the `contract:` field in `compose.yaml` to the shared no-deploy address `0x6273AB73C95Ba2233281F1eb8aa3b21D9352AD6d` unless the user is deploying their own (Step 3, Branch B).

## Preflight

The `goldsky` CLI, auth, and `deno` checks are the standard Compose preflight — see `/compose` and `/auth-setup`. VRF-specific: **`foundry`** (`forge --version`) is needed only on the deploy-your-own path (Step 3, Branch B).

## Step 1 — Configuration interview

Ask one question at a time; let each answer inform the next. Use readable labels and translate to machine values yourself.

1. **App name** — do NOT ask; name it `vrf-app` in the top-level `name:` of `compose.yaml`. The user can rename it after deploy.
2. **"Which chain?"** — **Base Sepolia (recommended)** because it has the ready, fully-unpermissioned shared contract (nothing to deploy). Other chains require deploying your own. Use the camelCase form in TS (`baseSepolia`) and snake_case in `compose.yaml` (`base_sepolia`).
3. **"RandomnessConsumer contract?"** (ask right after the chain) — two options:
   - **Reuse the shared contract on Base Sepolia (recommended)** — nothing to deploy. Wire `0x6273AB73C95Ba2233281F1eb8aa3b21D9352AD6d` (mention the address in prose, not in any option label). Demos/getting-started only, not production.
   - **Deploy my own** — see Step 3, Branch B. (Required on any chain other than Base Sepolia.)

## Step 2 — Wallet

- **Shared-contract path (recommended):** nothing to do. The Compose smart wallet is auto-created at runtime and fully gas-sponsored on Base Sepolia, and the shared contract is permissionless so there's no fulfiller to authorize. Do NOT tell the user to create or fund a wallet.
- **Deploy-your-own path:** if your contract restricts fulfillment, you need the wallet address *before* deploying so you can pass it as the authorized fulfiller. Provision the named wallet (matches `evm.wallet({ name: "randomness-fulfiller" })` in `src/tasks/fulfill-randomness.ts`) and capture its address as `$COMPOSE_WALLET`:
  ```bash
  goldsky compose wallet create randomness-fulfiller
  ```

## Step 3 — Contract

**Branch A — Reuse shared contract (recommended).** `$CONTRACT_ADDRESS = 0x6273AB73C95Ba2233281F1eb8aa3b21D9352AD6d` on Base Sepolia. No deploy, no fulfiller authorization. Skip to Step 4.

**Branch B — Deploy your own.** Write the reference contract from **The app (full source)** above to `contracts/RandomnessConsumer.sol`, then output this for the user to run with their own funded EOA (the constructor arg is recorded as the fulfiller label):

```bash
forge create contracts/RandomnessConsumer.sol:RandomnessConsumer \
  --rpc-url <RPC_URL_FOR_CHOSEN_CHAIN> \
  --private-key $PRIVATE_KEY \
  --constructor-args $COMPOSE_WALLET \
  --broadcast
```

RPC URLs: `baseSepolia` → `https://sepolia.base.org`, `base` → `https://mainnet.base.org`, `arbitrumSepolia` → `https://sepolia-rollup.arbitrum.io/rpc`, `optimismSepolia` → `https://sepolia.optimism.io`. Tell the user `$PRIVATE_KEY` must be an EOA with gas on the target chain. Capture `Deployed to: 0x...` as `$CONTRACT_ADDRESS`.

## Step 4 — Wire the contract address and chain into code

Three places must stay in sync. Use grep anchors — line numbers shift over time.

**`compose.yaml`**:
- Top-level `name:` → `"<app name>"`.
- Inside the `onchain_event` trigger: `network:` → `"<chosen chain in snake_case>"` and `contract:` → `"<CONTRACT_ADDRESS>"`.

**`src/tasks/fulfill-randomness.ts`** and **`src/tasks/request-randomness.ts`** (both):
- `const CONTRACT_ADDRESS = "0x..."` → `<CONTRACT_ADDRESS>`.
- The `evm.chains.baseSepolia` reference inside `new evm.contracts.RandomnessConsumer(...)` → `evm.chains.<chosen chain in camelCase>`.

Show a diff before applying, then apply with Edit.

## Step 5 — Gas (deploy-your-own, non-sponsored chains only)

Compose-managed wallets default to `sponsorGas: true` on sponsored chains (including Base Sepolia). On those chains the wallet needs no funding — skip this step. On a non-sponsored chain, send a small amount of native gas token to `$COMPOSE_WALLET` (testnet faucet, e.g. https://www.alchemy.com/faucets/base-sepolia).

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

First deploy may take 1–2 minutes. Watch for `Deployed compose app: <app_name>` and the HTTP task URLs in the output.

## Step 8 — Smoke test

Trigger a request against the deployed app. The simplest way is the `request_randomness` HTTP task, which exercises the full request → event → fulfill path:

```bash
curl -X POST \
  -H "Authorization: Bearer $COMPOSE_TOKEN" \
  "https://api.goldsky.com/api/admin/compose/v1/<app name>/tasks/request_randomness"
```

(`$COMPOSE_TOKEN` is a Compose API token from the Goldsky dashboard. `goldsky compose callTask` only invokes locally running tasks, not the deployed app.) Or call the contract directly:

```bash
cast send $CONTRACT_ADDRESS "requestRandomness()" \
  --rpc-url <RPC_URL> \
  --private-key $PRIVATE_KEY
```

Wait 10–30 seconds for Compose to pick up the event, then tail logs:

```bash
goldsky compose logs
```

You should see `fetched drand round <N>` and `fulfilled request <requestId> in tx <hash>`. Verify on-chain:

```bash
cast call $CONTRACT_ADDRESS "isFulfilled(uint256)(bool)" <requestId> --rpc-url <RPC_URL>
# → true
```

## Troubleshooting

- **Edits to `compose.yaml` or source files don't take effect after redeploy.** The local `.compose/` bundle cache is stale. Run `rm -rf .compose/` and redeploy.
- **`OnlyFulfiller()` revert on `fulfillRandomness`.** You pointed the app at a *permissioned* contract (e.g. the old `0xE05Ceb…` demo) instead of the open `0x6273AB…`, or your own contract restricts fulfillment to an address that isn't the Compose wallet. Use the shared open contract, or set your contract's fulfiller to `$COMPOSE_WALLET`.
- **Task doesn't fire when the event is emitted.** Confirm `compose.yaml` has the exact `contract:` address and the correct `network:`, the deploy succeeded, and the trigger is active (`goldsky compose status`).
- **`insufficient funds for gas`.** Only possible on a non-sponsored chain. Fund `$COMPOSE_WALLET`.
- **drand fetch fails.** The default drand endpoint is public. The retry config in `compose.yaml` (max 3, backoff) handles transient failures. If it persistently fails, check https://api.drand.sh/chains.

## What you should NOT do

- Do not point the app at the permissioned `0xE05Ceb3E269029E3bab46E35515e8987060D1027` demo — off-the-shelf fulfillment reverts there. The shared no-deploy contract is `0x6273AB73C95Ba2233281F1eb8aa3b21D9352AD6d`.
- Do not modify the drand constants in `src/lib/drand.ts` unless the user explicitly asks to swap drand networks. They are chain-specific BLS parameters; getting them wrong breaks signature verification silently.
- Do not change the event signature `RandomnessRequested(uint256,address)` in `compose.yaml` — it must match the contract.
- Do not use the shared Base Sepolia contract as a production target — it's open for anyone to fulfill.
- Do not add a `PRIVATE_KEY` secret to this app. The Compose wallet is the signer; the user's EOA is only needed to deploy their own contract, never at runtime.

## Related

- **`/compose`** — Build a new/custom Compose app from scratch, or explain what Compose is.
- **`/compose-reference`** — Manifest, CLI, TaskContext API, wallets, gas sponsorship, codegen.
- **`/compose-doctor`** — Diagnose and fix a broken Compose app.
- **`/auth-setup`** — `goldsky login` walkthrough.
