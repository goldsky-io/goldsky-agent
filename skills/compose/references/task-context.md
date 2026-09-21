# TaskContext API

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
