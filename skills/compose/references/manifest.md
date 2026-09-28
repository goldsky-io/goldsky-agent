# Compose manifest, codegen, dashboard, pricing

> **Sandbox import rule — get this wrong and the task fails to bundle or crashes at runtime.** Two things are NEVER imported: the Compose runtime capabilities and the EVM SDK. `env`, `fetch`, `callTask`, `logEvent`, `evm` (wallets, chains, contracts, `decodeEventLog`), and `collection` all come from the injected `context` argument — there is no `@goldsky/compose-evm` (or similar) package to import; reach chains via `context.evm.chains.<name>`, never by importing `viem` for them. Beyond that, what you may import depends on whether the app has a `package.json`:
> - **No `package.json` (Deno-style app, e.g. bitcoin-oracle):** import ONLY the `compose` module (for types, `import type { TaskContext } from "compose"`) and sibling project files (`./lib/utils`, `../contracts/Foo`). Any other bare import is rejected by the bundler.
> - **Has a `package.json` (esbuild-bundled, e.g. copy-trader with `viem`/`@ethersproject/wallet`, solana with `gill`):** npm deps declared there ARE bundled and importable for **local/pure** use (crypto, signing, encoding). The hard limit is the network: Compose tasks run in a sandbox with no outbound socket of their own, so any package that does its own HTTP at runtime (`axios`, `node-fetch`, an SDK's built-in HTTP client) fails — route every network call through `context.fetch` and use only the SDK's pure utilities.
>
> So: match the example you're scaffolding from. If it ships a `package.json`, keep its npm imports; if it doesn't, don't introduce any.

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

## Dashboard

URL pattern:

```
https://app.goldsky.com/<project_id>/dashboard/compose/<app-name>
https://app.goldsky.com/<project_id>/dashboard/compose/<app-name>/runs/<run_id>
```

The dashboard shows status, secret **names**, logs, a Code tab file browser, a Download app button, and per-run traces. Build run URLs from a run id returned by `compose runs`.

## Pricing

Pricing is not published. Usage is metered on three dimensions: **function calls** (`compose_function_calls`), **worker hours** (`compose_worker_hours`), and **gas spend** (`compose_gas_spend`). Gas spent by `writeContract` and `deployContract` is billed the same as runtime task gas. Per-unit prices are set per contract, so point the user at https://goldsky.com/pricing rather than quoting a tier.
