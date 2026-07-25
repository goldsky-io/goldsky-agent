---
name: compose-reference
description: "Load this skill whenever building, editing, or deploying a Goldsky Compose app — it is the reference layer that gives the concrete rules for how to build one: the exact shape of compose.yaml (every top-level, task, and trigger field), every `goldsky compose` CLI flag, the TaskContext API (env, fetch, callTask, logEvent, evm, collection), wallet APIs (smart wallet, BYO EOA), gas sponsorship, contract codegen, the dashboard URL, and pricing. Consult it before writing or editing any compose.yaml or task file — do not synthesize the manifest/CLI/API shape from memory — and also to answer any user question about how Compose works or what a field, flag, or API does. Pairs with /compose (the entry-point build guide, loaded first); use /compose-doctor to debug a broken app. Do NOT load for Turbo, Mirror, Subgraphs, or Edge — those have their own reference skills."
---

# Goldsky Compose Reference

Reference for the `compose.yaml` manifest, the full `goldsky compose` CLI surface, the `TaskContext` API, wallets, gas sponsorship, contract codegen, the dashboard, and pricing. For interactive build flows use `/compose`; for debugging use `/compose-doctor`.

> This is the **reference layer** of the Compose skill family. `/compose` (loaded first) carries the general build rules and concepts; the template skills (`/compose-bitcoin-oracle`, `/compose-vrf`, `/compose-dividend-distribution`, `/compose-compliance-oracle`) carry example app source. Load this skill for any concrete field, flag, manifest shape, or API signature — and always before writing a `compose.yaml` or task file, rather than synthesizing the shape from memory.

> **Always validate the manifest before deploying.** `goldsky compose start` catches schema errors fast.

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
| `name`        | string               | yes         | `/^[a-zA-Z0-9]([a-zA-Z0-9_\-]*[a-zA-Z0-9])?$/`, starts and ends with a letter or number; letters, numbers, underscores, hyphens. Uppercase and leading digits are allowed. The platform additionally rejects a name that canonicalizes (lowercase, `[-_]+`->`-`) onto an existing app's, with a 409, so `my-app`, `My_App`, and `my__app` cannot coexist |
| `api_version` | string               | deploy-only | semver (e.g. `0.1.0`) or `stable` / `preview` / `canary` (any `internal-*` prefix is also accepted) |
| `tasks`       | array                | yes         | Non-empty                                                                             |
| `secrets`     | string[]             | no          | Names only — values set via `compose secret set`                                      |
| `env`         | `{ local?, cloud? }` | no          | **`env`'s only valid children are `local` and `cloud`** — each a `Record<string, string>` flattened into `context.env`. A bare `env.MY_VAR` (a var name directly under `env`) is rejected: "not a valid key". A hardcoded per-app constant belongs in the task file, not here. |

### Task fields

| Field          | Type     | Required | Notes                                                                                |
| -------------- | -------- | -------- | ------------------------------------------------------------------------------------ |
| `name`         | string   | yes      | `/^[a-zA-Z0-9][a-zA-Z0-9_.\-]*$/`, starts with a letter or number; letters, numbers, underscores, hyphens, dots. A **leading underscore is no longer allowed** (`_internal_task` is now rejected) |
| `path`         | string   | yes      | Relative path to the `.ts` task file                                                 |
| `triggers`     | array    | yes      | One or more; at most one per type                                                    |
| `retry_config` | object   | no       | `{ max_attempts, initial_interval_ms, backoff_factor }` - all three required when set; the manifest validator rejects a task with any field outside `name`, `path`, `retry_config`, `triggers` |

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

All commands accept `-t/--token` and `--api-server`; the `-n/--name` flag selects the app by name (falls back to `-m/--manifest`, then `./compose.yaml`). Token precedence is `--token` > the `GOLDSKY_API_TOKEN` env var > `~/.goldsky/auth_token` (written by `goldsky login`). With none of the three the CLI errors with "Please run goldsky login, set GOLDSKY_API_TOKEN, or pass --token to the command."

> **Non-interactive guards.** `init` without a name, `deploy` with a major `api_version` mismatch (needs `--force`, message "Refusing to deploy with a major api_version mismatch in non-interactive mode. Pass --force to override."), and `clean` without `-f` ("Use --force for non-interactive cleanup.") all abort in a non-TTY. Agents always run non-TTY.

### Lifecycle

| Command                            | Purpose                                                  | Key flags                                                                  |
| ---------------------------------- | -------------------------------------------------------- | -------------------------------------------------------------------------- |
| `compose init`                   | Scaffold new app                                          | `[name]` (prompts only when a TTY and no name)                              |
| `compose start`                  | Run locally (there is no `dev` command)                 | `--fork-chains`, `--cloud`, `--impersonate`, `-p/--port`                   |
| `compose deploy`                 | Bundle + upload to cloud                                | `-m`, `-t`, `-f` (Skip version compatibility prompts (required to deploy with a major version mismatch when not running in a terminal)), `--sync-env`, `--json` |
| `compose status`                 | Show runtime status                                     | `-n`, `--json`                                                             |
| `compose list`                   | List all apps                                           | `--json`                                                                   |
| `compose history`                | Show deployment history for an app                      | `-n`, `--limit` (default 20, server caps at 100), `--offset` (default 0), `--include-failures`, `--json` |
| `compose pause`                  | Pause                                                   | `-n`, `--json`                                                             |
| `compose resume`                 | Resume                                                  | `-n`, `--json`                                                             |
| `compose delete`                 | Delete (type-to-confirm; `--force` for CI)              | `-n`, `--force`, `--delete-database`, `--json`                             |
| `compose logs`                   | View / tail logs                                        | `-f`, `--tail` (default 100), `--level`, `--search`, `--since`, `--max-lines`, `--timeout <duration>`, `--json` |
| `compose clean`                  | Wipe local `.compose/stage.db`                          | `-f`, `-c/--config <config>`                                               |
| `compose update [version]`       | Re-download the compose binary                          | `[version]` (stable/preview/semver), `--preview`                           |
| `compose callTask <task_name> <payload>` | Invoke a task with a JSON payload. **Defaults to the deployed app** | `--env <local\|cloud>` (default `cloud`), `-p/--port <port>` (implies local; `--port` with an explicit `--env cloud` is an error), `-n`, `-m`, `-t`, `--api-server`, `--json` |

Local port resolution for `callTask --env local`: `--port` flag > `.compose/.port` > 4000. Connection refused, an unknown task name, and a stale port file each produce a distinct message and exit 1 (codes `CONNECTION_REFUSED`, `TASK_NOT_FOUND`, `INVALID_RESPONSE`, `INVALID_PAYLOAD`, `INVALID_ENV`, `INVALID_FLAGS`).

### Secrets

| Command                                                                              | Purpose                  |
| ------------------------------------------------------------------------------------ | ------------------------ |
| `compose secret set <SECRET_NAME> --value <value> [-n <app>] [--env local\|cloud] [--redeploy]` | Set a secret (name is positional; `-n` = app)            |
| `compose secret delete <secret_name> [-n <app>] [--env local\|cloud]`                           | Delete                                                    |
| `compose secret list [-n <app>]`                                                                | List (no `--env` flag)                                    |
| `compose deploy --sync-env`                                                                     | Upload all of `.env` to cloud at deploy time (there is no `secret sync`) |

### Wallets

| Command                                               | Purpose                                                                |
| ----------------------------------------------------- | ---------------------------------------------------------------------- |
| `compose wallet create <wallet_name> [-n <app>] [--env local\|cloud] [--json]` | Create managed wallet; prints address (name is positional; `-n` = app) |
| `compose wallet list [-n <app>] [--env local\|cloud] [--json]`                 | Table: name, address, type (privy / private_key / tevm), created_at    |

### Codegen

`compose codegen` — parse all `src/contracts/*.json` ABIs, write `.compose/generated/index.ts` and `.compose/types.d.ts`. Runs automatically inside `compose init`, `compose start`, and during deploy.

### Contracts

Compile and deploy a contract, or submit a write call, straight from the CLI — no Foundry needed (`deployContract` bundles solc). Added in 0.8.0; the forge-style multi-arg/array constructor syntax needs ≥ 0.8.1 — run `goldsky compose update` if you're older.

**`compose deployContract <file.sol>`** — compiles in-CLI and deploys via a CREATE2 proxy through the app's Compose wallet. The forge-style multi-arg/array constructor syntax needs ≥ 0.8.1.

| Flag | Purpose |
| --- | --- |
| `--chain-id <id>` | Target chain (**required**). e.g. Base Sepolia `84532`, Base `8453`, Polygon `137`, Polygon Amoy `80002`, Arbitrum `42161`, Optimism `10`. |
| `--constructor-args <tokens...>` | Forge-style: space-separated, one token per param; arrays `"[a,b]"`, tuples `"(a,b)"`, nesting allowed, negatives `" -5"` (quoted leading space). Coerced against the compiled ABI. |
| `--wallet <name>` | App wallet that deploys (default `default`). Match the `evm.wallet({ name })` the task code uses when the contract must authorize that wallet. |
| `--verify` | Verify the contract on the block explorer. |
| `--force` | Bypass the `msg.sender`-in-constructor guard (the sender is the CREATE2 proxy, not the wallet). |
| `-m` / `-t` | Manifest path / project token (see Lifecycle). |
| `--api-server` | API server URL (global flag). |
| `--json` | JSON output (see CLI JSON Schemas). |

Run from the app directory - it reads `compose.yaml` for the app name; app name + project id derive the deterministic CREATE2 salt. On gas-sponsored chains (Base `8453`, Base Sepolia `84532`) it needs **no funded key and no RPC URL**. `deployContract` routes through the cloud's Alchemy bundler, which covers Ethereum, Sepolia, Polygon, Polygon Amoy, Arbitrum, Arbitrum Sepolia, Optimism, Optimism Sepolia, Base and Base Sepolia (chain IDs 1, 11155111, 137, 80002, 42161, 421614, 10, 11155420, 8453, 84532). On a chain outside that set the deploy fails with `No Alchemy bundler URL for chain <id>`, so use the `forge create` fallback there (the constructor args stay the same; supply the ABI to `src/contracts/` yourself). Multi-provider coverage is tracked as FOU-991. Runtime task-gas sponsorship (see [Gas Sponsorship](#gas-sponsorship)) covers many more chains than this deploy endpoint.

**Wallet lifecycle.** `wallet create` and `wallet list` now work even before the app is deployed (they provision the hosted store on demand, like `deployContract`/`writeContract`); `wallet create` returns the wallet's address pre-deploy. To authorize a wallet inside a constructor: `wallet create <name>` → `deployContract --constructor-args <address>` → wire the address into the task → `compose deploy`.

**CREATE2 collisions.** Re-deploying the same contract source + constructor args from the same app hits a CREATE2 collision: the platform returns HTTP 400 `CONTRACT_ALREADY_DEPLOYED` and the CLI reports "This contract has already been deployed with this app. The same contract + app name + project produces the same address via CREATE2." with exit 1 and no Deploy Block (`--json` code `ALREADY_DEPLOYED`; any other deploy failure is `DEPLOY_CONTRACT_FAILED`). A changed constructor arg, changed source, or a different app name produces a fresh address. Note the **app name participates in the CREATE2 salt** - renaming the app changes every future deploy address. On success it prints the contract address, tx hash, and **Deploy Block**, and **auto-saves the ABI to `src/contracts/<Name>.json`** - then `compose codegen` gives typed bindings.

**`compose writeContract`** — submit a write call to a deployed contract.

| Flag | Purpose |
| --- | --- |
| `--chain-id <id>` | Target chain (**required**). |
| `--to <address>` | Target contract address (**required**). |
| `--function "sig(types)"` | Function signature, e.g. `"setValue(uint256)"`. |
| `--args <tokens...>` | Same forge-style grammar as `--constructor-args`. |
| `--data <hex>` | Raw calldata alternative to `--function` / `--args`. |
| `--value <amount>` | Native value to send; suffix a unit (`wei`, `gwei`, `ether`), e.g. `--value 1ether`. |
| `--wallet <name>` | App wallet that signs (default `default`). |
| `--api-server` | API server URL (global flag). |
| `--json` | JSON output (see CLI JSON Schemas). |

### Read-back

| Command | Purpose | Key flags |
| --- | --- | --- |
| `compose runs [runId]` | List runs, or show one run's detail | `--limit`, `--offset`, `--task <name>`, `--status <success\|error\|pending>`, `--since <1h\|30m\|7d>`, `--until <duration>`, `--json`, `-n`/`-m`, `-t`, `--api-server` |
| `compose collections list` | Table of the app's collection names | targeting + `--json` |
| `compose collections query <collectionName>` | Query one collection | `--filter <json>` (must be a JSON object), `--limit` (default 100, backend max 1000), `--offset`, `--json`, targeting |
| `compose source [taskName]` | Print the deployed app's source file list, or one task's source. Never writes to disk | targeting + `--json` |
| `compose download` | Download the deployed app's source archive | `-o/--output <path>` (default `<app>.zip`, refuses to overwrite an existing file), `--json`, targeting |

## TaskContext API

`main(context: TaskContext, params?: Record<string, unknown>): Promise<unknown>` receives:

```ts
type TaskContext = {
  env: Record<string, string>;
  logger: {
    info(message: string, data?: Record<string, unknown>): void;
    warn(message: string, data?: Record<string, unknown>): void;
    error(message: string, data?: Record<string, unknown>): void;
  };
  fetch: FetchFn;
  callTask: <Args, T>(name: string, args: Args, retryConfig?: RetryConfig) => Promise<T>;
  logEvent: (event: { code: string; message: string; data?: unknown }) => Promise<void>;
  evm: {
    chains: Record<string, Chain>;              // re-exported from viem internally — access via context.evm.chains.<name>, do NOT import viem
    wallet: (config: WalletConfig) => Promise<IWallet>;
    decodeEventLog: <T>(abi: AbiItem[], log: OnchainEvent) => Promise<T>;
    contracts: Record<string, ContractClass>;   // populated by codegen
  };
  collection: <T>(name: string, indexes?: CollectionIndexSpec[]) => Promise<Collection<T>>;
  sideEffect: <T>(fn: () => T | Promise<T>) => Promise<T>;
};
```

**No `secrets` namespace.** Secrets flatten into `context.env`. For output: `context.logger.info/warn/error(message, data?)` is the structured, run-correlated logger (each line carries `taskName`, `runId`, `appId`, `level`, `timestamp`). `console.log` is fine for free-form output. `logEvent` still works but is marked `@deprecated` in the runtime types and will be removed in a future major version.

### `fetch` (overloads)

```ts
type FetchConfig = {
  method?: string;                                  // defaults to "GET"
  headers?: Record<string, string>;
  body?: Record<string, unknown> | string;          // objects are JSON.stringify'd
};

interface FetchFn {
  <T>(url: string, retryConfig?: RetryConfig): Promise<T | undefined>;
  <T>(url: string, config?: FetchConfig, retryConfig?: RetryConfig): Promise<T | undefined>;
}
```
- The second argument is a **config object**, not a bare body: `ctx.fetch(url, { method: "POST", body: { a: 1 }, headers: { "X-Key": k } })`. Passing a raw payload object as the second argument does not send a body. Unrecognized keys are dropped and the request goes out as a GET.
- A non-2xx response **throws** `Fetch failed with status <code> <statusText>: <body>`.
- The response is JSON-parsed and returns `undefined` when the body is not JSON.
- This is not `window.fetch`. Use this, not native `fetch`.

### `callTask`

```ts
callTask<Args, T>(name: string, args: Args, retryConfig?: RetryConfig): Promise<T>
```

- `T` is whatever the callee returns. A `void`-returning task resolves to `undefined`.
- Use for task-to-task invocation (parent/child patterns).

### `sideEffect`

```ts
sideEffect<T>(fn: () => T | Promise<T>): Promise<T>
```

Wraps a non-deterministic value (timestamp, UUID, random) so it is cached like any other context call. Durable resumption replays a task from the start, so an unwrapped `Date.now()` changes on replay. The callback runs once. On replay the host returns the cached value and the callback never runs.

### `RetryConfig`

```ts
type RetryConfig = {
  max_attempts: number;         // ≥0
  initial_interval_ms: number;  // >0
  backoff_factor: number;       // >0
};
```

All three fields are required **when you pass a `retryConfig` explicitly** (the manifest validator enforces this for `retry_config` too). Omitting it does **not** mean one attempt:

| Scope | Default |
| --- | --- |
| A task with no `retry_config` | `{ max_attempts: 3, initial_interval_ms: 1000, backoff_factor: 2 }` |
| Safe/read-only context calls: `readContract`, `simulate`, `getBalance`, and `ctx.fetch` with `GET`/`HEAD`/`OPTIONS` | `{ max_attempts: 3, initial_interval_ms: 500, backoff_factor: 2 }` |
| Everything else (`callTask`, `writeContract`, `sendTransaction`, `prepareUserOperation`, `submitSignedUserOperation`, wallet create/save, and `ctx.fetch` with POST/PUT/PATCH/DELETE) | `{ max_attempts: 1, initial_interval_ms: 500, backoff_factor: 2 }`, held at 1 deliberately to avoid blind retries of non-idempotent calls |

### `OnchainEvent` (for `decodeEventLog` and `onchain_event` triggers)

```ts
type OnchainEvent = {
  blockNumber: number;
  blockHash: string;
  transactionIndex: number;
  removed: boolean;
  address: string;
  data: Hex;
  topics: Hex[];
  transactionHash: string;
  logIndex: number;
};
```

For `onchain_event`-triggered tasks, `params` contains `{ log: OnchainEvent }` plus chain-specific metadata. `decodeEventLog(abi, params.log)` returns the decoded struct.

### IWallet

```ts
interface IWallet {
  readonly name: string;
  readonly address: Address;
  writeContract(
    chain: Chain,
    contractAddress: Address,
    functionSig: string,                 // signature string only, no ABI item
    args: unknown[],
    confirmation?: TransactionConfirmation,
    retryConfig?: RetryConfig,
  ): Promise<{ hash: string; receipt: TransactionReceipt; userOpHash?: string }>;
  sendTransaction(
    config: {
      to: Address; data: Hex; chain: Chain;
      value?: bigint; maxFeePerGas?: bigint; maxPriorityFeePerGas?: bigint;
      gas?: bigint; nonce?: number;
    },
    confirmation?: TransactionConfirmation,
    retryConfig?: RetryConfig,
  ): Promise<{ hash: string; receipt: TransactionReceipt; userOpHash?: string }>;
  readContract<T = unknown>(
    chain: Chain, contractAddress: Address, functionSig: string,
    args: unknown[], retryConfig?: RetryConfig,
  ): Promise<T>;
  simulate(                              // throws on revert
    chain: Chain, contractAddress: Address, functionSig: string,
    args: unknown[], retryConfig?: RetryConfig,
  ): Promise<unknown>;                   // viem simulateContract result
  getBalance(chain: Chain, retryConfig?: RetryConfig): Promise<string>; // decimal wei string
}

type TransactionConfirmation = {
  confirmations?: number;
  onReorg?: {
    action:
      | { type: "replay" }
      | { type: "log"; logLevel?: "error" | "info" | "warn" }   // default "error"
      | { type: "task"; task: string };
    depth: number;
  };
};
```

`TransactionReceipt` carries `status: "success" | "reverted"`, `blockNumber: bigint`, `blockHash`, `gasUsed: bigint`, `effectiveGasPrice: bigint`, `cumulativeGasUsed: bigint`, `from`, `to`, `contractAddress: Address | null`, `logs: Log[]`, `logsBloom`, `transactionHash`, `transactionIndex`, `type`.

Specifically: there is no `string | AbiItem` overload; `retryConfig` is a separate 6th positional arg, not a key in an options bag; there are no `gas`/`gasPrice` options on `writeContract`; the return has no `chainId` and no top-level `blockNumber` (the `TxResult` type as documented does not exist); `sendTransaction` is object-first, the positional `(chain, to, value, data?, options?)` form does not exist; `simulate` returns `{ result, request }` and throws on revert, so `SimulateResult { success, ... }` and `if (!sim.success)` are dead code; `getBalance` returns a decimal wei **string**, so arithmetic without `BigInt(...)` string-concatenates; `onReorg.action.type` is `"replay" | "log" | "task"`, there is no `"skip"`.

### Collection

```ts
type CollectionIndexSpec = {
  path: string;
  type: "text" | "numeric" | "boolean" | "timestamptz";
  unique?: boolean;
};

interface Collection<T> {
  readonly name: string;
  insertOne(doc: T, opts?: { id?: string }): Promise<{ id: string }>;
  findOne(filter: Filter): Promise<(T & { id: string }) | null>;
  findMany(filter: Filter, options?: { limit?: number; offset?: number }): Promise<Array<T & { id: string }>>;
  getById(id: string): Promise<(T & { id: string }) | null>;
  setById(id: string, doc: T, opts?: { upsert?: boolean }): Promise<{ id: string; upserted?: boolean; matched?: number }>; // upsert defaults true; false throws if absent
  deleteById(id: string): Promise<{ deletedCount: number }>;
  drop(): Promise<void>;
}
```

`collection<T>(name, indexes?)` takes `CollectionIndexSpec[]`, not `string[]`. `findMany` options are `{ limit?, offset? }`: `skip` does not exist and is silently ignored, so paging written against it always returns page 1. Reads return `T & { id: string }`. A filter is flat `Record<string, string | number | boolean | HelperValue>`, so nested-path filters are not supported.

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

`status` is one of `RUNNING`, `PAUSED`, `STARTING`, `STOPPING`, `ERROR`, `NOT_FOUND` (the value comes from the API, so treat the list as non-exhaustive). Timestamps are ms epoch.

### `compose list --json`

```json
[
  { "name": "my-app", "status": "RUNNING", "created_at": 1771630350411, "updated_at": 1774473580871 }
]
```

### `compose logs --json`

NDJSON (one object per line):

```json
{"timestamp":"2026-04-20T10:00:00Z","level":"info","message":"..."}
```
Exactly three fields. There is no `dashboard_url` in CLI log output. To link a user to a specific run, get the run id from `compose runs` and build `https://app.goldsky.com/<project_id>/dashboard/compose/<app-name>/runs/<run_id>` yourself. The CLI's `logs` command also has no `--run-id` filter (the underlying API accepts one, the CLI does not pass it), so use `compose runs <runId>` for per-run detail.

### `compose secret list -n <app> --json`

```json
[{ "name": "MY_SECRET", "created_at": 1771630350411 }]
```

Values are never returned.

### `compose wallet list --json`

```json
[{ "name": "updater", "address": "0x...", "type": "privy", "created_at": 1771630350411 }]
```

`type` is one of `privy` (smart wallet), `private_key` (BYO EOA), `tevm` (local forked).

### Errors in `--json` mode

In `--json` mode stdout carries only the result document (ascii art and progress bars are suppressed). Failures go to **stderr** as `{"error": true, "code": "<CODE>", "message": "..."}` with exit 1. Codes present in the CLI: `VALIDATION_FAILED`, `SECRET_MISSING`, `DEPLOY_FAILED`, `DEPLOY_CONTRACT_FAILED`, `ALREADY_DEPLOYED`, `WRITE_CONTRACT_FAILED`, `WALLET_CREATE_FAILED`, `WALLET_LIST_FAILED`, `NOT_FOUND`, `TASK_NOT_FOUND`, `CONNECTION_REFUSED`, `INVALID_ENV`, `INVALID_FLAGS`, `INVALID_PAYLOAD`, `INVALID_RESPONSE`, `INVALID_FILTER`, `UNKNOWN`.

## Wallets — Deep Dive

### Smart wallet (managed, Privy-backed)

```ts
const w = await evm.wallet({ name: "my-oracle" }); // sponsorGas defaults TRUE
```

Created cloud-side by Privy. Address is persisted. **Gas-sponsored by default.** **Cannot be used in plain local dev** - throws `"You cannot use a named wallet without a private key in local dev. Start with "goldsky compose start --fork-chains" for full wallet support, or use a private key wallet: const wallet = await evm.wallet({ privateKey: MY_SECRET }); See https://docs.goldsky.com/compose/secrets for more info on private key wallets"` Use `compose start --fork-chains` or switch to a BYO EOA for local iteration.

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

A chain is runtime-sponsorable if **any** of the three bundler providers covers it (tried in fallback order Alchemy → Pimlico → Gelato, each gated on its API keys being set). In the 0.8.1 source that union spans **112 chains**. This is the **runtime** task-gas sponsorship set - far broader than the `deployContract` / `writeContract` cloud *deploy* path, which covers the 10-chain Alchemy set (1, 11155111, 137, 80002, 42161, 421614, 10, 11155420, 8453, 84532; FOU-991 tracks broader coverage); runtime sponsorship also covers the Arbitrum, Optimism (incl. **Arbitrum Sepolia (`421614`)** / Optimism Sepolia (`11155420`)), Polygon, Ethereum and BNB families, among many others. **Don't hardcode the list** - it changes; confirm current coverage on the Goldsky docs chains page.

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

(Also runs automatically during `init`, `start`, and `deploy`.)

### Output

`.compose/generated/index.ts` exports a class per ABI. `.compose/types.d.ts` declares ambient types under the `compose` path alias (referenced in the scaffolded `tsconfig.json`).

### Consume in a task

```ts
import type { TaskContext } from "compose";

export async function main({ evm, env }: TaskContext) {
  const wallet = await evm.wallet({ name: "oracle" });
  const PriceFeed = evm.contracts.PriceFeed;

  // Read — generated view methods call wallet.readContract under the hood
  const feed = new PriceFeed(env.FEED_ADDRESS, evm.chains.ethereum, wallet);
  const price = await feed.latestAnswer();

  // Write — generated state-changing methods call wallet.writeContract under the hood
  const tx = await feed.setPrice(1234n);
  return { price: price.toString(), hash: tx.hash };
}
```

Classes are exposed under `context.evm.contracts.<Name>`. Codegen names ending in `Class` (e.g. `ERC20Class`) are exposed as `ERC20` at runtime. The generated constructor is `new <Name>(address, chain, wallet)` — pass an `IWallet` from `evm.wallet(...)`; view methods read through it, state-changing methods write through it, both subject to the wallet's gas-sponsorship setting.

## Supported Chains

`context.evm.chains` is re-exported from `viem/chains`. Any chain viem knows, you can address as `evm.chains.<name>` (e.g. `evm.chains.polygonAmoy`, `evm.chains.monadTestnet`, `evm.chains.baseSepolia`). For **gas sponsorship** specifically, see the Gas Sponsorship section — sponsorship is a subset of viem's chain list.

## Dashboard

URL pattern:

```
https://app.goldsky.com/<project_id>/dashboard/compose/<app-name>
https://app.goldsky.com/<project_id>/dashboard/compose/<app-name>/runs/<run_id>
```

The dashboard shows status, secret **names**, logs, a Code tab file browser, a Download app button, and per-run traces. Build run URLs from a run id returned by `compose runs`.

## Pricing

Pricing is not published. Usage is metered on three dimensions: **function calls** (`compose_function_calls`), **worker hours** (`compose_worker_hours`), and **gas spend** (`compose_gas_spend`). Gas spent by `writeContract` and `deployContract` is billed the same as runtime task gas. Per-unit prices are set per contract, so point the user at https://goldsky.com/pricing rather than quoting a tier.

## Related

- **`/compose`** — Build a new app or explain what Compose is.
- **`/compose-doctor`** — Diagnose and fix broken apps.
- **`/auth-setup`** — `goldsky login` help.
- **`/secrets`** — General secret management.
