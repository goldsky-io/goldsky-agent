---
name: feeds
description: "Query Goldsky Feeds for one wallet's balances and transfers. Use for wallet holdings, portfolio value, transfer history, deposit checks, edge.goldsky.com/data/feeds, a Feeds API key, or GOLDSKY_FEEDS_API_KEY. The same key also serves Polymarket activity, positions and balances, and block headers by number, hash or timestamp. Use goldsky feeds key ensure, goldsky feeds balances, and goldsky feeds transfers. If a feeds subcommand is missing, stop. The CLI login token is not this key. For rows in the user's own database, use /turbo-builder. For a Turbo dataset name, use /datasets. For JSON-RPC, use /edge or /boost."
---

# Goldsky Feeds

Feeds answers one question about one wallet over HTTP: what it holds, or what it sent and received, across the supported chains in a single request. Goldsky indexes, normalizes, and prices the rows. The caller does not run a pipeline.

The same host and the same key also serve Polymarket and block-header feeds. Those are listed under "Other feeds on this key", and they do not follow the conventions below.

Use `goldsky feeds`. Do not mint the key with `goldsky edge create`. The endpoint name `feeds` is reserved on the Edge create path, so that command is rejected. The CLI login token is a different credential and does not authenticate these requests. If `goldsky feeds` is not a command, stop. Do not build an Authorization header, and do not print the Feeds key.

## When this is the wrong tool

- The rows need to land in the user's own database or webhook. That is a Turbo pipeline (`/turbo-builder`, `/datasets`). Feeds does not stream into a sink; streaming is not offered yet (https://docs.goldsky.com/feeds/streaming).
- The question is a Turbo dataset name or chain prefix. That is `/datasets`. Those prefixes differ: Feeds says `polygon` and `arbitrum_one`, Turbo says `matic` and `arbitrum`.
- The question is JSON-RPC. That is `/edge`, or `/boost` when they want to keep their current provider.

## Key

A project has one Feeds key, and every feed answers it. Ensure it with the CLI. Do not send the user to the dashboard, and do not run `goldsky edge create`.

```bash
goldsky feeds key ensure
```

If that subcommand is missing, stop. Do not build an Authorization header. Do not print the Feeds key. Do not pass `--token`. If the CLI says they are not logged in, use `/auth-setup` first. The caller has to be an Editor on the project.

Do not rotate the key unless the user asks: rotate revokes the current key immediately.

## Calls

```bash
goldsky feeds balances --address 0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045
goldsky feeds transfers --address 0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045
```

Balances returns the latest balance of each token the wallet holds, native assets included, plus `total_value_usd`. Transfers returns that wallet's movements, newest first. `direction` is `in` or `out` relative to `address`.

If either subcommand is missing, stop. Do not rebuild these as HTTP requests, and do not build an Authorization header.

Read https://edge.goldsky.com/data/openapi.json before using a parameter or response field that the quickstart does not show. That document is the contract. The guide is https://docs.goldsky.com/feeds/quickstart and the overview is https://docs.goldsky.com/feeds.

Both feeds can also answer 502 when ClickHouse upstream fails, and balances can answer 503 when native balances are unavailable on some chains. The 503 names them in `error.chains` and sets `Retry-After`; it is a partial outage, so retry rather than reporting the wallet as empty.

`address` is required and is exactly one wallet. An EVM address is `0x` plus 40 hex digits. A base58 Solana address passes validation but has no chain behind it yet, so it answers 200 with an empty `data`. A non-200 body is an error, not an empty wallet.

## Parameters

Re-read `goldsky feeds balances --help` and the OpenAPI spec when a request is rejected. Pass these as flags on `goldsky feeds balances` or `goldsky feeds transfers`. Do not fall back to HTTP, and do not build an Authorization header. The chain set lives on the `chains` parameter.

- Omit `chains` to query every supported chain. Pass canonical slugs, comma-separated. `matic`, `arbitrum`, and `mainnet` are aliases for `polygon`, `arbitrum_one`, and `ethereum`. Matching is case-insensitive, and `-` is read as `_`. Any other spelling returns 400.
- `token_symbol` matches a symbol, so two contracts can both match — `usdc` returns both the native and the bridged contract on several chains at once. Use `token_address` when the token must be a specific contract; it takes up to 100, comma-separated. On balances, the zero address selects the native asset of every chain in scope.
- `include_unknown_price` defaults to false, which leaves out tokens Goldsky has no price *source* for. It is not a promise that every row is priced: at the default, rows whose token is priceable still come back with `price_usd` and `value_usd` null. Handle a null price on every row.
- `include_historical` defaults to false. Set it to true on balances to also get zero rows: tokens fully sold, and natives the wallet holds none of. On one wallet here that took 373 rows to 517. "Has this wallet ever held X" needs it; "what is it worth now" does not.
- `min_value_usd` drops rows below that USD value and also drops unpriced rows. It applies to `total_value_usd` too.
- On transfers, `from` and `to` are inclusive RFC 3339 bounds on `block_timestamp`. `from_block` and `to_block` require exactly one chain, because block numbers are not comparable across chains; without one they are 422 `CONFLICTING_FILTERS`, not 400. `transfer_type` is `native`, `erc20`, or both, comma-separated. The NFT types (`erc721`, `erc1155`) return 400. `spl` is accepted and returns 200 with an empty `data`, because no Solana chain is served yet: that empty page means the filter matched nothing on the EVM chains, not that the wallet is empty. `direction` is `in` or `out`.
- `page_size` defaults to 100 and the maximum is 1000. A larger value is clamped to 1000 rather than rejected, so read `pagination.page_size` back instead of assuming the request size was honored. The next page is `page_token` set to the previous response's `pagination.next_page_token`. A token is only valid for the filters that produced it. Each page is a separate billed request (https://docs.goldsky.com/pricing/summary#feeds). Do not walk the whole history unless the user asked for that range.

## Other feeds on this key

`/polymarket/activity`, `/polymarket/positions`, `/polymarket/balances`, `/blocks/{chain}` and `/blocks/{chain}/head` are served by the same host and the same key. A Polymarket question does not have to become a pipeline: reach for `/turbo-builder` only when the rows have to land in the user's own database. If `goldsky feeds` has no subcommand for the path, stop. Do not print the Feeds key and do not build an Authorization header. Read the OpenAPI spec before calling one, because all three of the conventions above change:

- **Pagination is `limit` and `cursor`, not `page_size` and `page_token`,** and the next cursor is `next_cursor` at the top level, not `pagination.next_page_token`. `page_size` is accepted and silently ignored, so a request meaning to ask for 2 rows returns the default 100 — and every one of those is billed. Check what came back.
- **The chain vocabulary is not the wallet feeds' vocabulary.** `/blocks` serves 21 chains and spells Polygon `matic`; `polygon`, `mainnet` and every `arbitrum` spelling are 400 there. The wallet feeds serve 7 and spell it `polygon`, with `matic` only an alias. A slug that works on one is not known to work on the other.
- **Errors are not always the `{"error":{"code","message"}}` envelope.** A bad query string on these paths comes back as a bare string (`Failed to deserialize query string: ...`), so reading `.error.message` gets null. Branch on the status code, not on the body shape.
- **Numbers are scaled differently per path.** `/polymarket/activity` serves JSON numbers already in decimals (`price: 0.65`, `amount_shares: 84.615385`, `amount_usdc: 55.0`, and `amount_usdc / amount_shares == price`). `/polymarket/positions` and `/polymarket/balances` serve strings in raw 1e6 integer units, so `avg_price: "100000"` is $0.10 and `amount: "12120000000"` is 12120 shares. Divide by 1e6 before showing either to a user. `positions.amount` and `balances.balance` share that scale but are **not** the same quantity and disagreed on half the rows sampled here: `amount` is the trade-derived net position, `balance` is the conditional-token balance actually held, and splits, merges, redeems and plain transfers move tokens without a fill. Pick the one that answers the question and do not substitute one for the other.
- **`/polymarket/activity` refuses an unselective scan.** It needs one of `address`, `token_id`, a closed block window of 300000 blocks or fewer, a closed time window of 604800 seconds or fewer, or `limit` of 100 or fewer with no filter. Anything else is 400 `MISSING_SELECTIVE_FILTER`.
- **Three values carry warnings in the spec.** `activity.fee`'s basis is inconsistent across some maker/taker pairs in the source data. `positions.last_updated_at` is pipeline upsert time, not block time, so rows with different `block_number` can share it; use `block_number` to order. `balances.as_of_block` is the latest balance at or before that block by insert order, not a reconstruction of that block.

## Writing code against a response

- Balances are the latest amount of each token, not a history. Several transfers in one block become one balance row. Reconstruct movement from the transfers feed.
- A transfer object has no id. Do not build a primary key that includes `block_number` or `block_timestamp`: a transaction that survives a reorg comes back with different block fields. Do not assume one transaction emits a transfer only once.
- `price_usd` and `amount_usd` are computed when the request is served. A later read of the same transfer can show a different USD value.
