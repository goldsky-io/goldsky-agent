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
| `compose init`                   | Scaffold new app (prompts for a name)                   | (interactive)                                                              |
| `compose start`                  | Run locally (there is no `dev` command)                 | `--fork-chains`, `--cloud`, `--impersonate`, `-p/--port`                   |
| `compose deploy`                 | Bundle + upload to cloud                                | `-m`, `-t`, `-f`, `--sync-env`                                             |
| `compose status`                 | Show runtime status                                     | `-n`, `--json`                                                             |
| `compose list`                   | List all apps                                           | `--json`                                                                   |
| `compose history`                | Show deployment history for an app                      | `-n`, `--limit`, `--include-failures`, `--json`                            |
| `compose pause`                  | Pause                                                   | `-n`                                                                       |
| `compose resume`                 | Resume                                                  | `-n`                                                                       |
| `compose delete`                 | Delete (type-to-confirm; `--force` for CI)              | `-n`, `--force`, `--delete-database`                                       |
| `compose logs`                   | View / tail logs                                        | `-f`, `--tail`, `--level`, `--search`, `--since`, `--max-lines`, `--json`  |
| `compose clean`                  | Wipe local `.compose/stage.db`                          | `-f`                                                                       |
| `compose update [version]`       | Re-download the compose binary                          | `[version]` (stable/preview/semver), `--preview`                           |
| `compose callTask <name> <json>` | POST payload to a local task                            |                                                                            |

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
| `compose wallet create <wallet_name> [-n <app>] [--env local\|cloud]` | Create managed wallet; prints address (name is positional; `-n` = app) |
| `compose wallet list [-n <app>] [--env local\|cloud]`                 | Table: name, address, type (privy / private_key / tevm), created_at    |

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

Run from the app directory — it reads `compose.yaml` for the app name; app name + project id derive the deterministic CREATE2 salt. On gas-sponsored chains (Base `8453`, Base Sepolia `84532`) it needs **no funded key and no RPC URL**. The cloud deploy path is Base / Base Sepolia only today (broader coverage tracked as FOU-991) — on other chains deploy with `forge create` from a funded EOA instead (the constructor args stay the same; supply the ABI to `src/contracts/` yourself). Runtime task-gas sponsorship (see [Gas Sponsorship](#gas-sponsorship)) covers many more chains than this deploy endpoint.

**Wallet lifecycle.** `deployContract` and `writeContract` provision the named wallet on demand — they work even before the app has ever been deployed. By contrast, `compose wallet create` / `wallet list` hit an app-scoped endpoint and fail with "Compose app not found. Deploy the app first, then create wallets." until the app has been `compose deploy`ed at least once, so **there is no way to learn a wallet's address before the first deploy** (a deploy tx's `from` is a relayer, not the wallet). To authorize a wallet inside a constructor: deploy the app → `wallet create <name>` → `deployContract --constructor-args <address>` → wire the address → redeploy.

**CREATE2 collisions.** Re-running `deployContract` with identical contract source + constructor args + app name is refused by the CLI *before* any transaction is sent ("This contract has already been deployed with this app…"), and no Deploy Block is printed on that refusal. A changed constructor arg, changed source, or a different app name produces a fresh address. Note the **app name participates in the CREATE2 salt** — renaming the app changes every future deploy address. On success it prints the contract address, tx hash, and **Deploy Block**, and **auto-saves the ABI to `src/contracts/<Name>.json`** — then `compose codegen` gives typed bindings.

**`compose writeContract`** — submit a write call to a deployed contract.

| Flag | Purpose |
| --- | --- |
| `--chain-id <id>` | Target chain (**required**). |
| `--to <address>` | Target contract address. |
| `--function "sig(types)"` | Function signature, e.g. `"setValue(uint256)"`. |
| `--args <tokens...>` | Same forge-style grammar as `--constructor-args`. |
| `--data <hex>` | Raw calldata alternative to `--function` / `--args`. |
| `--value <amount>` | Native value to send; suffix a unit (`wei`, `gwei`, `ether`), e.g. `--value 1ether`. |
| `--wallet <name>` | App wallet that signs (default `default`). |

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

Created cloud-side by Privy. Address is persisted. **Gas-sponsored by default.** **Cannot be used in plain local dev** — throws `"You cannot use a smart wallet in local dev unless you use chain forking."` Use `compose start --fork-chains` or switch to a BYO EOA for local iteration.

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

A chain is runtime-sponsorable if **any** of the three bundler providers covers it (tried in fallback order Alchemy → Pimlico → Gelato, each gated on its API keys being set). In the 0.8.1 source that union spans **112 chains**. This is the **runtime** task-gas sponsorship set — far broader than the `deployContract` / `writeContract` cloud *deploy* path, which is Base (`8453`) / Base Sepolia (`84532`) only for now (FOU-991); runtime sponsorship also covers the Arbitrum, Optimism (incl. **Arbitrum Sepolia (`421614`)** / Optimism Sepolia (`11155420`)), Polygon, Ethereum and BNB families, among many others. **Don't hardcode the list** — it changes; confirm current coverage on the Goldsky docs chains page.

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
