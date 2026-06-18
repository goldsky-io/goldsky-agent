# Schema, Manifest, and Mappings

Authoring reference for code-based Goldsky subgraphs. Goldsky runs standard `graph-node`, so the schema (`schema.graphql`), manifest (`subgraph.yaml`), and AssemblyScript mapping APIs (`@graphprotocol/graph-ts`) are the standard subgraph toolchain — only the deploy command differs (`goldsky subgraph deploy`, not `graph deploy --studio`).

## Schema design (`schema.graphql`)

Entities are GraphQL types annotated with `@entity`. Each needs an `id` field.

### Scalar type choices

| Use for | Type | Notes |
|---------|------|-------|
| Addresses, tx hashes, byte IDs | `Bytes` | Half the storage of a hex `String`, faster comparisons. Prefer over `String` for any hex value. |
| Token amounts, balances, timestamps, block numbers | `BigInt` | 256-bit integers. |
| Prices, ratios, derived decimals | `BigDecimal` | Arbitrary precision; slower than `BigInt` — only when you need fractions. |
| Flags | `Boolean` | |
| Enumerations | `enum` | Define once, reference in fields. |
| Auto-incrementing timeseries id | `Int8` | Required for timeseries entities (see performance.md). |

> **Bytes sort by hex value, not numerically.** If you need to sort/paginate entities in sequence, add an explicit `BigInt` index field rather than relying on a `Bytes` id.

### IDs

Build stable, collision-free IDs:
- Per-event row: `event.transaction.hash.concatI32(event.logIndex.toI32())`.
- Composite key: concatenate the parts (`account.concat(token)`), keeping `Bytes`.
- Singletons (e.g. a protocol-wide stats entity): a constant string id like `"global"`.

Avoid reusing an id across different entity types — overlapping ids cause "Conflicting key for entity" errors.

### Relationships

- **One-to-many:** store the reference on the *child* and derive on the *parent* with `@derivedFrom`:
  ```graphql
  type Pool @entity {
    id: Bytes!
    swaps: [Swap!]! @derivedFrom(field: "pool")
  }
  type Swap @entity {
    id: Bytes!
    pool: Pool!
  }
  ```
  Never store a growing array directly on the parent — large arrays are catastrophically slow (see performance.md). `@derivedFrom` is virtual (no storage, fast).
- **Many-to-many:** model a join entity (e.g. `PoolMembership { pool, account }`).

### Immutable entities

Mark entities that are written once and never updated as immutable:
```graphql
type Transfer @entity(immutable: true) { id: Bytes! ... }
```
graph-node skips block-range/version tracking for immutable entities, so they index and query faster. Use for append-only event records (transfers, swaps, mints). Do **not** use for anything that updates after creation (balances, pool reserves, positions).

## Manifest (`subgraph.yaml`)

Core structure:
```yaml
specVersion: 1.2.0          # 1.2.0+ required for declared eth_calls
schema:
  file: ./schema.graphql
dataSources:
  - kind: ethereum
    name: MyContract
    network: mainnet         # use the correct Goldsky chain slug
    source:
      address: "0x..."
      abi: MyContract
      startBlock: 12985438
    mapping:
      kind: ethereum/events
      apiVersion: 0.0.9       # keep ONE apiVersion across all dataSources
      language: wasm/assemblyscript
      entities: [Pool, Swap]
      abis:
        - name: MyContract
          file: ./abis/MyContract.json
      eventHandlers:
        - event: Swap(indexed address,indexed address,int256,int256,uint160,uint128,int24)
          handler: handleSwap
      file: ./src/mapping.ts
```

Handler kinds:
- `eventHandlers` — react to emitted events (most common). The `event:` signature must match the ABI exactly, including `indexed`.
- `callHandlers` — react to contract function calls (needs trace support; enable with `--enable-call-handlers` for instant subgraphs).
- `blockHandlers` — run per block (or filtered). Expensive; use sparingly.

### Templates (factory pattern)

For contracts created at runtime (e.g. a DEX factory deploying pools), declare a `templates:` data source and instantiate it from a handler:
```ts
import { Pool as PoolTemplate } from "../generated/templates"
// in handlePoolCreated:
PoolTemplate.create(event.params.pool)
// with context:
let ctx = new DataSourceContext()
ctx.setBytes("token0", event.params.token0)
PoolTemplate.createWithContext(event.params.pool, ctx)
```
Read context inside the template's handlers via `dataSource.context()`.

### Grafting

Goldsky fully supports grafting (start a new version from an existing version's data at a block):
```yaml
features: [grafting]
graft:
  base: <base-deployment-id>
  block: 12345678
```
You cannot graft at a pruned block (see performance.md). Use `--graft-from <name>/<version>` / `--remove-graft` on deploy.

## AssemblyScript mapping idioms (`src/`)

After editing the schema/manifest, regenerate types with codegen so `../generated/schema` and contract bindings exist. (Missing-type or unknown-field compile errors usually mean codegen wasn't re-run.)

### Get-or-create

```ts
function getOrCreatePool(id: Bytes): Pool {
  let pool = Pool.load(id)
  if (pool == null) {
    pool = new Pool(id)
    pool.totalVolume = BigInt.zero()   // initialize EVERY non-nullable field
  }
  return pool
}
```
Always initialize all non-nullable fields on create, and always `.save()` before the handler returns.

### Revert-safe contract calls

A contract call that reverts will abort the handler with a fatal `unexpected null`. Use `try_`:
```ts
let contract = ERC20.bind(tokenAddress)
let decimalsResult = contract.try_decimals()
let decimals = decimalsResult.reverted ? 18 : decimalsResult.value   // sensible default, never skip the save
```
> This is the single most common cause of crashing subgraphs: a non-ERC-20 contract whose `decimals()`/`symbol()` reverts, an early-return that skips `.save()`, then a later `.load()` panics on the missing entity. Default the value, persist the entity, skip only the downstream pricing.

### Safe math

```ts
function safeDiv(a: BigDecimal, b: BigDecimal): BigDecimal {
  return b.equals(BigDecimal.zero()) ? BigDecimal.zero() : a.div(b)
}
// decimal conversion: amount / 10^decimals
let scaled = amount.toBigDecimal().div(
  BigInt.fromI32(10).pow(decimals as u8).toBigDecimal()
)
```

## Instant subgraph enrichment

Instant (no-code) subgraphs configure indexing via JSON instead of AssemblyScript. You can still enrich entities with `eth_call` results and computed expressions. The expression runtime context exposes `event` (or `call`), the parent `entity` (already saved before enrichment), and `calls` (results of previously executed eth_calls). Mark a call `required` to force ordering. **Declared calls** (`declared: true`) run in parallel for a big perf boost but only work for calls with no mapping-handler dependency (computable from event params alone), and are ignored on call handlers. See performance.md and `docs.goldsky.com/subgraphs/guides/create-a-low-code-subgraph`.

## Protocol recipes (schema sketches)

- **ERC-20:** `Token` (immutable: symbol, name, decimals) + `Account` + `Balance(account+token id)` updated on `Transfer`; optional `Transfer` (immutable) log.
- **ERC-721/1155:** `Collection` + `Token(tokenId)` + `Account` + `Transfer` (immutable); track `owner` on `Token`.
- **DEX (Uniswap-style):** `Factory` template → `Pool`; `Swap`/`Mint`/`Burn` (immutable) `@derivedFrom` on `Pool`; `Token` with `derivedETH`/USD pricing computed via `try_` calls.
- **Lending:** `Market`, `Account`, `Position`, immutable `Borrow`/`Repay`/`Liquidation` events.
- **Governance:** `Proposal`, `Vote`, `Delegate`; track vote weights as `BigInt`.

Keep event records immutable and use `@derivedFrom` for the "list of X under Y" queries dApps need.
