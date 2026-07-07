---
name: compose-reference
description: "Load this skill whenever building, editing, or deploying a Goldsky Compose app — it is the reference layer that gives the concrete rules for how to build one: the exact shape of compose.yaml (every top-level, task, and trigger field), every `goldsky compose` CLI flag, the TaskContext API (env, fetch, callTask, logEvent, evm, collection), wallet APIs (smart wallet, BYO EOA), gas sponsorship, contract codegen, the dashboard URL, and pricing. Consult it before writing or editing any compose.yaml or task file — do not synthesize the manifest/CLI/API shape from memory — and also to answer any user question about how Compose works or what a field, flag, or API does. Pairs with /compose (the entry-point build guide, loaded first); use /compose-doctor to debug a broken app. Do NOT load for Turbo, Mirror, Subgraphs, or Edge — those have their own reference skills."
---

# Goldsky Compose Reference

Reference for the `compose.yaml` manifest, the full `goldsky compose` CLI surface, the `TaskContext` API, wallets, gas sponsorship, contract codegen, the dashboard, and pricing. For interactive build flows use `/compose`; for debugging use `/compose-doctor`.

> This is the **reference layer** of the Compose skill family. `/compose` (loaded first) carries the general build rules and concepts; the template skills (`/compose-bitcoin-oracle`, `/compose-vrf`, `/compose-dividend-distribution`, `/compose-compliance-oracle`) carry example app source. Load this skill for any concrete field, flag, manifest shape, or API signature — and always before writing a `compose.yaml` or task file, rather than synthesizing the shape from memory.

> **Always validate the manifest before deploying.** `goldsky compose dev` catches schema errors fast.

> **Sandbox import rule — get this wrong and the task fails to bundle or crashes at runtime.** Two things are NEVER imported: the Compose runtime capabilities and the EVM SDK. `env`, `fetch`, `callTask`, `logEvent`, `evm` (wallets, chains, contracts, `decodeEventLog`), and `collection` all come from the injected `context` argument — there is no `@goldsky/compose-evm` (or similar) package to import; reach chains via `context.evm.chains.<name>`, never by importing `viem` for them. Beyond that, what you may import depends on whether the app has a `package.json`:
> - **No `package.json` (Deno-style app, e.g. bitcoin-oracle):** import ONLY the `compose` module (for types, `import type { TaskContext } from "compose"`) and sibling project files (`./lib/utils`, `../contracts/Foo`). Any other bare import is rejected by the bundler.
> - **Has a `package.json` (esbuild-bundled, e.g. copy-trader with `viem`/`@ethersproject/wallet`, solana with `gill`):** npm deps declared there ARE bundled and importable for **local/pure** use (crypto, signing, encoding). The hard limit is the network: Compose tasks run in a sandbox with no outbound socket of their own, so any package that does its own HTTP at runtime (`axios`, `node-fetch`, an SDK's built-in HTTP client) fails — route every network call through `context.fetch` and use only the SDK's pure utilities.
>
> So: match the example you're scaffolding from. If it ships a `package.json`, keep its npm imports; if it doesn't, don't introduce any.

## Quick Reference

Most common lookups:

- **Manifest top-level / task / trigger fields** → [compose.yaml Manifest](#composeyaml-manifest)
- **CLI flags** → [CLI Commands](#cli-commands)
- **TaskContext shape, IWallet, Collection** → [TaskContext API](#taskcontext-api)
- **Smart wallet vs BYO EOA, gas sponsorship defaults** → [Wallets — Deep Dive](#wallets--deep-dive)
- **Contract codegen workflow** → [Contract Codegen](#contract-codegen-full-example)
- **`--json` output shapes** → [CLI JSON Schemas](#cli-json-schemas)
- **Dashboard URL** → [Dashboard](#dashboard)

## compose.yaml Manifest

### Top-level fields

| Field         | Type                 | Required    | Notes                                                                                 |
| ------------- | -------------------- | ----------- | ------------------------------------------------------------------------------------- |
| `name`        | string               | yes         | RFC 1123: lowercase, letters/numbers/hyphens, letter-start                            |
| `api_version` | string               | deploy-only | semver (e.g. `0.1.0`) or `stable` / `preview` / `canary`                              |
| `tasks`       | array                | yes         | Non-empty                                                                             |
| `secrets`     | string[]             | no          | Names only — values set via `compose secret set`                                      |
| `env`         | `{ local?, cloud? }` | no          | **`env`'s only valid children are `local` and `cloud`** — each a `Record<string, string>` flattened into `context.env`. A bare `env.MY_VAR` (a var name directly under `env`) is rejected: "not a valid key". A hardcoded per-app constant belongs in the task file, not here. |

### Task fields

| Field          | Type     | Required | Notes                                                                                |
| -------------- | -------- | -------- | ------------------------------------------------------------------------------------ |
| `name`         | string   | yes      | `/^([a-zA-Z]\|_[a-zA-Z0-9])[a-zA-Z0-9_]*$/`                                          |
| `path`         | string   | yes      | Relative path to the `.ts` task file                                                 |
| `triggers`     | array    | yes      | One or more; at most one per type                                                    |
| `retry_config` | object   | no       | `{ max_attempts, initial_interval_ms, backoff_factor }` — all three required when set |

### Trigger types

**cron**

```yaml
- type: cron
  expression: "*/15 * * * *" # 5-field cron
```

**http**

```yaml
- type: http
  authentication: auth_token # or "none"
  ip_whitelist: ["1.2.3.4", "10.0.0.0/8"] # optional, IPv4/IPv6/CIDR
```

**onchain_event**

```yaml
- type: onchain_event
  network: polygon_amoy # snake_case required
  contract: "0xYourContractAddress" # 0x + 40 hex
  events:
    - "Transfer(address,address,uint256)" # viem signature strings, optional
  dataset_version: "..." # optional
```

### Full manifest example

```yaml
name: my-app
api_version: stable
secrets:
  - COINGECKO_API_KEY
  - ORACLE_SIGNER_KEY
env:
  cloud:
    LOG_LEVEL: info
  local:
    LOG_LEVEL: debug
tasks:
  - name: update_oracle
    path: src/tasks/update-oracle.ts
    retry_config:
      max_attempts: 3
      initial_interval_ms: 1000
      backoff_factor: 2
    triggers:
      - type: cron
        expression: "*/5 * * * *"
  - name: manual_trigger
    path: src/tasks/manual-trigger.ts
    triggers:
      - type: http
        authentication: auth_token
```

## CLI Commands

All commands accept `-t/--token` and `--api-server`; the `-n/--name` flag selects the app by name (falls back to `-m/--manifest`, then `./compose.yaml`).

### Lifecycle

| Command                            | Purpose                                                  | Key flags                                                                  |
| ---------------------------------- | -------------------------------------------------------- | -------------------------------------------------------------------------- |
| `compose init [name]`              | Scaffold new app                                         | (interactive)                                                              |
| `compose dev`                      | Run locally (alias: `start`)                             | `--fork-chains`, `--cloud`                                                 |
| `compose deploy`                   | Bundle + upload to cloud                                 | `-m`, `-t`, `-f`, `--sync-env`                                             |
| `compose status`                   | Show runtime status                                      | `-n`, `--json`                                                             |
| `compose list`                     | List all apps                                            | `--json`                                                                   |
| `compose pause`                    | Pause                                                    | `-n`                                                                       |
| `compose resume`                   | Resume                                                   | `-n`                                                                       |
| `compose delete`                   | Delete (type-to-confirm; `--force` for CI)               | `-n`, `--force`, `--delete-database`                                       |
| `compose logs`                     | View / tail logs                                         | `-f`, `--tail`, `--level`, `--search`, `--since`, `--max-lines`, `--json`  |
| `compose clean`                    | Wipe local `.compose/stage.db`                           | `-f`                                                                       |
| `compose update`                   | Re-download the compose binary                           | `--preview`                                                                |
| `compose callTask <name> <json>`   | POST payload to a local task                             |                                                                            |

### Secrets

| Command                                                                              | Purpose                  |
| ------------------------------------------------------------------------------------ | ------------------------ |
| `compose secret set --name X --value Y [--env local\|cloud] [--redeploy]`            | Set a secret             |
| `compose secret delete --name X [--env local\|cloud]`                                | Delete                   |
| `compose secret list [--env local\|cloud]`                                           | List                     |
| `compose secret sync`                                                                | Upload all of `.env` to cloud |

### Wallets

| Command                                               | Purpose                                                                |
| ----------------------------------------------------- | ---------------------------------------------------------------------- |
| `compose wallet create --name X [--env local\|cloud]` | Create managed wallet; prints address                                  |
| `compose wallet list`                                 | Table: name, address, type (privy / private_key / tevm), created_at    |

### Codegen

`compose codegen` — parse all `src/contracts/*.json` ABIs, write `.compose/generated/index.ts` and `.compose/types.d.ts`. Runs automatically inside `compose init`, `compose dev`, and during deploy.

## TaskContext API

`main(context: TaskContext, params?: Record<string, unknown>): Promise<unknown>` receives:

```ts
type TaskContext = {
  env: Record<string, string>;
  fetch: FetchFn;
  callTask: <Args, T>(name: string, args: Args, retryConfig?: RetryConfig) => Promise<T>;
  logEvent: (event: { code: string; message: string; data?: unknown }) => Promise<void>;
  evm: {
    chains: Record<string, Chain>;              // re-exported from viem internally — access via context.evm.chains.<name>, do NOT import viem
    wallet: (config: WalletConfig) => Promise<IWallet>;
    decodeEventLog: <T>(abi: AbiItem[], log: EventLog) => Promise<T>;
    contracts: Record<string, ContractClass>;   // populated by codegen
  };
  collection: <T>(name: string, indexes?: string[]) => Promise<Collection<T>>;
};
```

**No `logger` or `secrets` namespace.** Secrets flatten into `context.env`. Use `console.log` for free-form logging, `logEvent` for structured events.

### `fetch` (overloads)

```ts
interface FetchFn {
  <T>(url: string, retryConfig?: RetryConfig): Promise<T | undefined>;
  <T>(url: string, body: unknown, retryConfig?: RetryConfig): Promise<T | undefined>;
}
```

- `body` is serialized as JSON and sent as POST. Omit `body` for GET.
- Response is JSON-parsed; returns `undefined` when the body isn't JSON.
- Not `window.fetch` — use this, not native `fetch`.

### `callTask`

```ts
callTask<Args, T>(name: string, args: Args, retryConfig?: RetryConfig): Promise<T>
```

- `T` is whatever the callee returns. A `void`-returning task resolves to `undefined`.
- Use for task-to-task invocation (parent/child patterns).

### `RetryConfig`

```ts
type RetryConfig = {
  max_attempts: number;         // ≥0
  initial_interval_ms: number;  // >0
  backoff_factor: number;       // >0
};
```

No defaults — supply all three when you pass a `retryConfig`. Without it, the task runs once and any thrown error surfaces to the run record.

### `EventLog` (for `decodeEventLog` and `onchain_event` triggers)

```ts
type EventLog = {
  address: Address;     // "0x…"
  topics: Hex[];        // indexed topics
  data: Hex;            // non-indexed data
  blockNumber?: bigint;
  transactionHash?: Hex;
  logIndex?: number;
};
```

For `onchain_event`-triggered tasks, `params` contains `{ log: EventLog }` plus chain-specific metadata. `decodeEventLog(abi, params.log)` returns the decoded struct.

### IWallet

```ts
interface IWallet {
  readonly name: string;
  readonly address: Address;
  writeContract(
    chain: Chain,
    address: Address,
    signatureOrAbi: string | AbiItem,
    args?: unknown[],
    options?: WriteOptions,
  ): Promise<TxResult>;
  readContract(
    chain: Chain,
    address: Address,
    signatureOrAbi: string | AbiItem,
    args?: unknown[],
  ): Promise<unknown>;
  sendTransaction(
    chain: Chain,
    to: Address,
    value: bigint,
    data?: Hex,
    options?: WriteOptions,
  ): Promise<TxResult>;
  simulate(
    chain: Chain,
    address: Address,
    signatureOrAbi: string | AbiItem,
    args?: unknown[],
  ): Promise<SimulateResult>;
  getBalance(chain: Chain): Promise<bigint>;
}

type WriteOptions = {
  confirmations?: number;
  onReorg?: { action: { type: "replay" | "skip" }; depth: number };
  retryConfig?: RetryConfig;
  gas?: bigint;
  gasPrice?: bigint;
};

type TxResult = {
  hash: Hex;
  userOpHash?: Hex;     // only for sponsored transactions
  chainId: number;
  blockNumber?: bigint; // present after mining
};

type SimulateResult = {
  success: boolean;
  result?: unknown;
  error?: string;
};
```

### Collection

```ts
interface Collection<T> {
  insertOne(doc: T): Promise<void>;
  findOne(filter: Filter<T>): Promise<T | null>;
  findMany(filter: Filter<T>, options?: { limit?: number; skip?: number }): Promise<T[]>;
  getById(id: string): Promise<T | null>;
  setById(id: string, doc: T, opts?: { upsert?: boolean }): Promise<void>; // upsert defaults true
  deleteById(id: string): Promise<void>;
  drop(): Promise<void>;
}
```

Filter operators: `$gt`, `$gte`, `$lt`, `$lte`, `$in`, `$ne`, `$nin`, `$exists`. Equality: `{ field: value }`.

## CLI JSON Schemas

For agents parsing `--json` output:

### `compose status -n <app> --json`

```json
{
  "name": "my-app",
  "status": "RUNNING",
  "created_at": 1771630350411,
  "updated_at": 1774473580871
}
```

`status` is one of `RUNNING | PAUSED | ERROR | STARTING | STOPPED | PROVISIONING`. Timestamps are ms epoch.

### `compose list --json`

```json
[
  { "name": "my-app", "status": "RUNNING", "created_at": 1771630350411, "updated_at": 1774473580871 }
]
```

### `compose logs --json`

NDJSON (one object per line):

```json
{"timestamp":"2026-04-20T10:00:00Z","level":"info","message":"...","dashboard_url":"https://app.goldsky.com/<project_id>/dashboard/compose/<app>/runs/<run_id>"}
```

### `compose secret list -n <app> --json`

```json
[{ "name": "MY_SECRET" }]
```

Values are never returned.

### `compose wallet list --json`

```json
[{ "name": "updater", "address": "0x...", "type": "privy", "created_at": 1771630350411 }]
```

`type` is one of `privy` (smart wallet), `private_key` (BYO EOA), `tevm` (local forked).

## Wallets — Deep Dive

### Smart wallet (managed, Privy-backed)

```ts
const w = await evm.wallet({ name: "my-oracle" }); // sponsorGas defaults TRUE
```

Created cloud-side by Privy. Address is persisted. **Gas-sponsored by default.** **Cannot be used in plain local dev** — throws `"You cannot use a smart wallet in local dev unless you use chain forking."` Use `compose dev --fork-chains` or switch to a BYO EOA for local iteration.

### BYO EOA (private key)

```ts
const w = await evm.wallet({
  privateKey: env.MY_KEY,
  name: "my-pk-wallet",       // optional; defaults to the derived address
  sponsorGas: true,           // DEFAULTS TO FALSE — opt in explicitly
});
```

Works in both cloud and local. When `sponsorGas: true`, the wallet configures EIP-7702 delegation per chain on first use, then submits UserOperations through a sponsored bundler.

## Gas Sponsorship

Bundler fallback order: **Alchemy → Pimlico → Gelato**. Override via `BUNDLER_PROVIDER=<alchemy|pimlico|gelato>` env var.

### Supported chains

See the Goldsky docs chains page for the current list (don't hardcode — this changes). Highlights include Ethereum, Base, Arbitrum, Optimism, Polygon, Unichain, Monad (mainnet + testnet), MegaETH testnet, Lisk, Linea, Scroll, Avalanche, Blast, BNB, Celo, Zora, Sonic, Worldchain, plus major Sepolia testnets and Polygon Amoy.

### Error on unsupported chain

```
No bundler provider available for chain <id>. Providers: alchemy: chain not supported; pimlico: missing keys (PIMLICO_API_KEY); gelato: …
```

Either use a supported chain or set `sponsorGas: false` and fund the EOA manually.

### Caveats

- `onReorg` is **not** supported for gas-sponsored transactions (warning logged, not fatal).
- Passing a custom `nonce` to a sponsored `sendTransaction` is ignored (ERC-4337 smart wallets use a different nonce structure).

## Contract Codegen (full example)

### Input

Drop ABI JSON files into `src/contracts/`:

```
src/contracts/
├── ERC20.json
└── PriceFeed.json
```

**Accepted ABI shapes:** bare ABI array (`[{ "type": "function", ... }, ...]`), or wrapped object (`{ "abi": [...] }`), or a Foundry/Hardhat artifact (the generator extracts the `abi` field). The filename (without extension) becomes the generated class name.

### Generate

```bash
goldsky compose codegen
```

(Also runs automatically during `init`, `dev`, and `deploy`.)

### Output

`.compose/generated/index.ts` exports a class per ABI. `.compose/types.d.ts` declares ambient types under the `compose` path alias (referenced in the scaffolded `tsconfig.json`).

### Consume in a task

```ts
import type { TaskContext } from "compose";

export async function main({ evm, env }: TaskContext) {
  const PriceFeed = evm.contracts.PriceFeed;
  const feed = new PriceFeed(evm.chains.ethereum, env.FEED_ADDRESS);
  const price = await feed.latestAnswer();
  return { price: price.toString() };
}
```

Classes are exposed under `context.evm.contracts.<Name>`. Codegen names ending in `Class` (e.g. `ERC20Class`) are exposed as `ERC20` at runtime.

## Supported Chains

`context.evm.chains` is re-exported from `viem/chains`. Any chain viem knows, you can address as `evm.chains.<name>` (e.g. `evm.chains.polygonAmoy`, `evm.chains.monadTestnet`, `evm.chains.baseSepolia`). For **gas sponsorship** specifically, see the Gas Sponsorship section — sponsorship is a subset of viem's chain list.

## Dashboard

URL pattern:

```
https://app.goldsky.com/<project_id>/dashboard/compose/<app-name>
https://app.goldsky.com/<project_id>/dashboard/compose/<app-name>/runs/<run_id>
```

The dashboard shows status, secrets, logs, and per-run traces. Log lines include a `dashboard_url` attribute in their metadata so agents can link the user directly to the relevant run.

## Pricing

Compose is in **Beta**. Pricing is **enterprise-only** — schedule a call with Goldsky to discuss your use case. Source: https://goldsky.com/pricing (Compose section).

Internally, usage is tracked across three metered dimensions:

- **Function calls** (`compose_function_calls`) — number of task invocations.
- **Worker hours** (`compose_worker_hours`) — runtime consumed.
- **Gas spend** (`compose_gas_spend`) — gas paid for sponsored transactions.

These metrics drive enterprise-tier billing; per-unit prices are set per contract, not published.

## Related

- **`/compose`** — Build a new app or explain what Compose is.
- **`/compose-doctor`** — Diagnose and fix broken apps.
- **`/auth-setup`** — `goldsky login` help.
- **`/secrets`** — General secret management.
