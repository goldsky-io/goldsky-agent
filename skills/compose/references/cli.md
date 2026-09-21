# goldsky compose CLI

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
