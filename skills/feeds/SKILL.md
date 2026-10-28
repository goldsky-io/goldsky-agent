---
name: feeds
description: "Query Goldsky Feeds over HTTP: one wallet's balances and transfers; metadata and current USD price of up to 100 EVM tokens; Polymarket activity (a wallet's trades), positions, PnL and balances; block headers by number, hash or timestamp; and a chain's head block. Feeds absorbed Edge Data / Data APIs, with the same URLs and keys. Use for wallet holdings, portfolio value, transfer history, deposit checks, token prices or metadata, a wallet's Polymarket trades or positions, which block was at a timestamp, the latest indexed block, edge.goldsky.com/data, a Feeds API key, GOLDSKY_FEEDS_API_KEY, Feeds pricing, or paying per request with x402 instead of a key. Get the key with goldsky feeds key reveal, then call the feeds over HTTP. The CLI login token is not this key. For rows in the user's own database, use /turbo-builder. For a Turbo dataset name, use /datasets. For JSON-RPC, use /edge or /boost."
---

# Goldsky Feeds

Feeds is Goldsky's REST API for ready-made onchain data. Goldsky indexes and normalizes the rows, and prices the wallet and token rows. The caller does not run a pipeline. Every feed is a `GET` on `https://edge.goldsky.com/data` that returns JSON, and one key serves all of them.

| Theme | Feed | Path | Required input |
| --- | --- | --- | --- |
| Wallets | Transfers | `/feeds/wallets/transfers` | `address` |
| Wallets | Balances | `/feeds/wallets/balances` | `address` |
| Tokens | Tokens | `/feeds/tokens` | `tokens` (up to 100 `chain:token_address` pairs) |
| Prediction markets | Activity | `/polymarket/activity` | none (`address` optional, but see the selective-filter rule) |
| Prediction markets | Positions | `/polymarket/positions` | `address` |
| Prediction markets | Balances | `/polymarket/balances` | `address` |
| Network datasets | Blocks | `/blocks/{chain}` | `chain` (path) |
| Network datasets | Chain head | `/blocks/{chain}/head` | `chain` (path) |

The wallet feeds answer one question about one wallet: what it holds, or what it sent and received, across the supported chains in a single request. The tokens feed answers what a list of tokens is and what each is worth now, up to 100 per request. Prediction markets serves Polymarket (on Polygon) trades, positions and conditional-token balances. Network datasets serves block headers and each chain's head block.

Prediction markets and Network datasets used to be sold as "Edge Data" or "Data APIs". They are part of Feeds now. The URLs did not change and existing Data API keys keep working, so an integration built against them needs no change. Do not call the product "Edge Data" or "Data APIs" to the user except to say it was renamed.

Prediction markets and Network datasets do not follow the wallet feeds' conventions; read "Prediction markets and Network datasets" before calling them. Say "Prediction markets Balances" when the user could confuse it with wallet Balances. The tokens feed has its own section, "Tokens".

The CLI gets the key (`goldsky feeds key reveal`); the feeds themselves are plain HTTP. There are no `goldsky feeds` read commands. Do not mint the key with `goldsky edge create`. The endpoint name `feeds` is reserved on the Edge create path, so that command is rejected. The CLI login token is a different credential and does not authenticate these requests. Do not print the Feeds key.

## When this is the wrong tool

- The rows need to land in the user's own database or webhook. That is a Turbo pipeline (`/turbo-builder`, `/datasets`). Feeds does not stream into a sink; streaming is not offered yet (https://docs.goldsky.com/feeds/streaming).
- The question is a Turbo dataset name or chain prefix. That is `/datasets`. Those prefixes differ: the wallet and tokens feeds say `polygon` and `arbitrum_one`, Turbo says `matic` and `arbitrum`. Feeds' "Network datasets" are HTTP feeds read with a key, not Turbo datasets.
- The question is JSON-RPC. That is `/edge`, or `/boost` when they want to keep their current provider.

## Key

A project has one Feeds key, and every feed in the table answers it. Get it with the CLI yourself rather than sending the user to the dashboard, and do not run `goldsky edge create`.

```bash
goldsky feeds key reveal
export GOLDSKY_FEEDS_API_KEY="$(cat "$HOME/.goldsky/feeds-api-key")"
```

`reveal` creates the key if the project has none, otherwise fetches the existing one, and writes it to `~/.goldsky/feeds-api-key` (mode 600). It never prints the key and never rotates it, so it is safe to run again. Do not `cat` that file into the chat, and do not write the key anywhere else.

Success prints `Created Feeds API key and saved it to ~/.goldsky/feeds-api-key` or `Saved existing Feeds API key to ~/.goldsky/feeds-api-key`. If it prints the general help instead, the CLI is older than 13.17.0 (an older CLI exits 0 there, so read the output, not the exit code); run `/auth-setup` to install the pinned version. Do not pass `--token`. A 401 means they are not logged in: use `/auth-setup` first. A 403 means the user is not an Editor on the project. A 409 means an Edge endpoint named `feeds` exists and is not the Feeds key; that endpoint has to be deleted first.

Do not rotate the key unless the user asks: rotate revokes the current key immediately.

Without a shell, the same key is in the dashboard at **Feeds → API keys** (https://app.goldsky.com), and the Goldsky API returns it from `POST /api/v1/feeds/api-key`, creating it if the project has none. That call returns the plaintext key only when it creates the key. Existing Data API keys keep working on every feed and are managed in Feeds → API keys. Any team on a plan, Starter included, can get the Feeds key; a team with no plan is refused. Rate limits are set per plan, and Goldsky support raises them; there is no self-serve setting.

Send the key in the `x-api-key` header. `?key=` and `Authorization: Bearer` are also accepted, but prefer the header so the key does not land in a URL log. A missing key answers 402 with an x402 payment challenge (`PAYMENT-REQUIRED` header), not 401, because the feeds are also offered pay-per-request (see "Pay per request with x402"). A key that is present but wrong is 401. So on a 402, the header did not arrive; check that `GOLDSKY_FEEDS_API_KEY` is set before assuming the key is bad.

## Calls

```bash
curl -sS -H "x-api-key: $GOLDSKY_FEEDS_API_KEY" \
  "https://edge.goldsky.com/data/feeds/wallets/balances?address=0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045"
curl -sS -H "x-api-key: $GOLDSKY_FEEDS_API_KEY" \
  "https://edge.goldsky.com/data/feeds/wallets/transfers?address=0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045"
curl -sS -H "x-api-key: $GOLDSKY_FEEDS_API_KEY" \
  "https://edge.goldsky.com/data/feeds/tokens?tokens=ethereum:0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48,base:0x0000000000000000000000000000000000000000,base:0x833589fcd6edb6e08f4c7c32d4f71b54bda02913"
```

Balances returns the latest balance of each token the wallet holds, native assets included, plus `total_value_usd`. Transfers returns that wallet's movements, newest first. `direction` is `in` or `out` relative to `address`. Tokens returns `token_symbol`, `token_name`, `token_decimals`, `token_logo_url`, `price_usd` and `last_priced_at` for each pair named in `tokens`.

Read https://edge.goldsky.com/data/openapi.json before using a parameter or response field that the quickstart does not show. That document is the contract. The guide is https://docs.goldsky.com/feeds/quickstart and the overview is https://docs.goldsky.com/feeds.

All three can also answer 502 when ClickHouse upstream fails, and balances can answer 503 when native balances are unavailable on some chains. The 503 names them in `error.chains` and sets `Retry-After`; it is a partial outage, so retry rather than reporting the wallet as empty.

On the wallet feeds, `address` is required and is exactly one wallet. An EVM address is `0x` plus 40 hex digits. A non-200 body is an error, not an empty wallet.

## Parameters

Re-read the OpenAPI spec when a request is rejected. These are query parameters on the wallet feeds' URLs. The chain set lives on the `chains` parameter.

- Omit `chains` to query every supported chain. Pass canonical slugs, comma-separated. `matic`, `arbitrum`, and `mainnet` are aliases for `polygon`, `arbitrum_one`, and `ethereum`. Matching is case-insensitive, and `-` is read as `_`. Any other spelling returns 400.
- `token_symbol` matches a symbol, so two contracts can both match — `usdc` returns both the native and the bridged contract on several chains at once. Use `token_address` when the token must be a specific contract; it takes up to 100, comma-separated. On balances, the zero address selects the native asset of every chain in scope.
- `include_unknown_price` defaults to false, which leaves out tokens Goldsky has no price *source* for. It is not a promise that every row is priced: at the default, rows whose token is priceable still come back with `price_usd` and `value_usd` null. Handle a null price on every row.
- `include_historical` defaults to false. Set it to true on balances to also get zero rows: tokens fully sold, and natives the wallet holds none of. On one wallet here that took 373 rows to 517. "Has this wallet ever held X" needs it; "what is it worth now" does not.
- `min_value_usd` drops rows below that USD value and also drops unpriced rows. It applies to `total_value_usd` too.
- On transfers, `from` and `to` are inclusive RFC 3339 bounds on `block_timestamp`. `from_block` and `to_block` require exactly one chain, because block numbers are not comparable across chains; without one they are 422 `CONFLICTING_FILTERS`, not 400. `transfer_type` is `native`, `erc20`, or both, comma-separated. The NFT types (`erc721`, `erc1155`) return 400. `direction` is `in` or `out`.
- `page_size` defaults to 100 and the maximum is 1000. A larger value is clamped to 1000 rather than rejected, so read `pagination.page_size` back instead of assuming the request size was honored. The next page is `page_token` set to the previous response's `pagination.next_page_token`. A token is only valid for the filters that produced it. Each page is a separate billed request (https://docs.goldsky.com/pricing/summary#feeds). Do not walk the whole history unless the user asked for that range.

## Tokens

`/feeds/tokens` is not under `/feeds/wallets` and takes no `address`. Its only parameter is `tokens`: comma-separated `chain:token_address` pairs, at most 100. The cap counts distinct entries before alias and case folding: exact repeats are dropped first, but `mainnet:0xA0B8…` and `ethereum:0xa0b8…` use two of the 100. It serves current prices only, with no price history.

- The chain is one of `ethereum`, `base`, `arbitrum_one`, `optimism`, `polygon`, `bsc`, `robinhood`, `arc`, with the same aliases and folding as `chains`. Any other chain is 400.
- The address is `0x` plus 40 hex digits, any case. The zero address is the chain's native token, with the same symbol, name and decimals as its balances row (`base:0x000…000` is ETH, Ether, 18). Pairs are deduplicated after case and alias folding, so `mainnet:0xA0B8…` and `ethereum:0xa0b8…` together return one item.
- The response is `{"data":[...]}`: one item per distinct pair, in request order, with no pagination. Each item has `chain`, `chain_family`, `token_address`, `token_symbol`, `token_name`, `token_decimals`, `token_logo_url`, `price_usd` and `last_priced_at`. A token Goldsky knows nothing about is still listed, with every field after `token_address` null. Match items to the input by `(chain, token_address)`; both come back normalized (canonical slug, lowercase address). A null is not an error.
- `price_usd` follows the rule balances prices a row with, and uses only observations from the last 4 hours; without one it is null. `last_priced_at` is the time of that observation. A null `last_priced_at` beside a non-null `price_usd` is a major stablecoin asserted at par, not a stale price.
- A request bills the same whether it names 1 token or 100, and a 400 bills nothing (https://docs.goldsky.com/pricing/summary#feeds). To price a list, batch up to 100 pairs per request instead of one request per token.
- One bad entry rejects the whole request with 400 `BAD_REQUEST`, and the message says what is wrong: `` `tokens` is required: … ``, `` `tokens` entry is not a `chain:token_address` pair: base. ``, `` `tokens` entry has no chain: … ``, `` `tokens` entry has no EVM token address: base:0x12. … ``, `` Unsupported chain in `tokens`: avalanche. Supported: … `` (for several, the plural `` Unsupported chains in `tokens`: avalanche, bnb. Supported: … ``), `` At most 100 values may be passed in `tokens`; got 101. ``.

## Prediction markets and Network datasets

`/polymarket/activity`, `/polymarket/positions`, `/polymarket/balances`, `/blocks/{chain}` and `/blocks/{chain}/head` are served by the same host and the same key. A Polymarket or block question does not have to become a pipeline: reach for `/turbo-builder` only when the rows have to land in the user's own database. Call them the same way, with the `x-api-key` header.

```bash
# A wallet's Polymarket trades, newest first
curl -sS -H "x-api-key: $GOLDSKY_FEEDS_API_KEY" \
  "https://edge.goldsky.com/data/polymarket/activity?address=$WALLET&limit=50"
# A wallet's Polymarket positions, largest first
curl -sS -H "x-api-key: $GOLDSKY_FEEDS_API_KEY" \
  "https://edge.goldsky.com/data/polymarket/positions?address=$WALLET&limit=50"
# The newest Base block at or before a unix timestamp
curl -sS -H "x-api-key: $GOLDSKY_FEEDS_API_KEY" \
  "https://edge.goldsky.com/data/blocks/base?timestamp_lte=1767225600&sort=number_desc&limit=1"
# Ethereum's head block and how far behind wall-clock it is
curl -sS -H "x-api-key: $GOLDSKY_FEEDS_API_KEY" \
  "https://edge.goldsky.com/data/blocks/ethereum/head"
```

What each one answers, and the parameters that matter (the OpenAPI spec has the rest):

- **Activity** (`/polymarket/activity`) is trade fills and matches, plus splits, merges and redeems, newest first, with the counterparty on each maker row. Pass `address` for one wallet's trades. Filters: `address`, `token_id`, `event_type`, `side`, `order_type`, `start_time`/`end_time`, `start_block`/`end_block`, `min_amount_usdc`.
- **Positions** (`/polymarket/positions`) is one wallet's open positions per market token: `amount`, `avg_price`, `realized_pnl`, `total_bought`. `sort` is `amount_desc` (the default), `amount_asc`, `realized_pnl_desc` or `last_updated_at_desc`. `include_zero` and `min_amount` control which rows come back; `token_id` narrows to one market token.
- **Prediction markets Balances** (`/polymarket/balances`) is the conditional-token balance one wallet holds. Filters: `token_id`, `contract_address`, `token_type`, `min_balance`, `as_of_block`.
- **Blocks** (`/blocks/{chain}`) returns block headers: `number`, `hash`, `parent_hash`, `timestamp`, `gas_used`, `gas_limit`, `base_fee_per_gas`, `transaction_count`, and the roots. Look up one block with `number` or `hash` (each conflicts with the other and with the ranges), or filter with `number_gte`/`number_lte` or `timestamp_gte`/`timestamp_lte` (unix seconds). `sort` is `number_desc` (the default) or `number_asc`. "Which block was at time T" is `timestamp_lte=T&sort=number_desc&limit=1`.
- **Chain head** (`/blocks/{chain}/head`) returns one object, not a `data` array: `chain`, `number`, `timestamp`, and `head_lag_seconds`, the seconds between now and the head block. Use it as the freshness signal before trusting a recent range.
- The `chain` path segment is one of 21 slugs: `apechain`, `arbitrum-sepolia`, `base`, `blast`, `bsc`, `celo`, `ethereum`, `flare`, `gravity`, `hyperevm`, `linea`, `matic`, `optimism`, `plasma`, `plume`, `reya`, `robinhood`, `sei`, `worldchain`, `xai`, `xlayer`. This list is separate from the wallet feeds' chains; do not merge them.

Read the OpenAPI spec before calling one, because the wallet feeds' conventions do not carry over:

- **Pagination is `limit` and `cursor`, not `page_size` and `page_token`,** and the next cursor is `next_cursor` at the top level of `{"data":[...],"limit":N,"next_cursor":...}`, not `pagination.next_page_token`. Pass it back as `cursor`. `page_size` is accepted and silently ignored, so a request meaning to ask for 2 rows returns the default 100 — and every one of those is billed. Check what came back.
- **The chain vocabulary is not the wallet feeds' vocabulary.** `/blocks` serves 21 chains and spells Polygon `matic`; `polygon`, `mainnet` and every `arbitrum` spelling are 400 there. The wallet and tokens feeds share one EVM slug set, spell it `polygon`, and take `matic` only as an alias. A slug that works on one is not known to work on the other.
- **Errors are not always the `{"error":{"code","message"}}` envelope.** A bad query string on these paths comes back as a bare string (`Failed to deserialize query string: ...`), so reading `.error.message` gets null. Branch on the status code, not on the body shape.
- **Numbers are scaled differently per path.** `/polymarket/activity` serves JSON numbers already in decimals (`price: 0.65`, `amount_shares: 84.615385`, `amount_usdc: 55.0`, and `amount_usdc / amount_shares == price`). `/polymarket/positions` and `/polymarket/balances` serve strings in raw 1e6 integer units, so `avg_price: "100000"` is $0.10 and `amount: "12120000000"` is 12120 shares. Divide by 1e6 before showing either to a user. `positions.amount` and `balances.balance` share that scale but are **not** the same quantity and disagreed on half the rows sampled here: `amount` is the trade-derived net position, `balance` is the conditional-token balance actually held, and splits, merges, redeems and plain transfers move tokens without a fill. Pick the one that answers the question and do not substitute one for the other.
- **`/polymarket/activity` refuses an unselective scan.** It needs one of `address`, `token_id`, a closed block window of 300000 blocks or fewer, a closed time window of 604800 seconds or fewer, or `limit` of 100 or fewer with no filter. Anything else is 400 `MISSING_SELECTIVE_FILTER`.
- **Three values carry warnings in the spec.** `activity.fee`'s basis is inconsistent across some maker/taker pairs in the source data. `positions.last_updated_at` is pipeline upsert time, not block time, so rows with different `block_number` can share it; use `block_number` to order. `balances.as_of_block` is the latest balance at or before that block by insert order, not a reconstruction of that block.

## Pricing

Every feed bills on one meter: $10 per million compute units (CUs). Errors and empty results cost nothing. The full table is https://docs.goldsky.com/pricing/summary#feeds.

- **Wallet Transfers, wallet Balances, Tokens:** 35 CUs per request ($350 per million requests), whatever the page size or the number of tokens.
- **Prediction markets and Network datasets:** 1 CU per row returned ($10 per million rows). Chain head is 1 CU per call. Set `limit` to the rows the user needs: a left-out `limit` returns up to 100 rows, and each one bills.

## Pay per request with x402

Every feed can also be called with no Goldsky account and no key, paying per request with x402 in USDC through Circle Gateway. A keyless request answers `402` with a `PAYMENT-REQUIRED` header: a base64 JSON x402 v2 challenge (`scheme: exact`) that accepts USDC on Ethereum, Base, Avalanche, Arbitrum, Optimism, Polygon and more through Circle Gateway.

- **Wallet Transfers, wallet Balances, Tokens:** 350 atomic USDC ($0.00035) per request.
- **Prediction markets and Network datasets:** 10 atomic USDC ($0.00001) per request, flat, whatever the row count.

Each payment is a $0.005 (5000 atomic USDC) top-up that later requests spend down: about 14 wallet or Tokens requests, or about 500 Prediction markets or Network datasets requests. The balance belongs to the paying wallet and is shared with Edge RPC's x402. Do not write the payment flow from this summary; follow https://docs.goldsky.com/edge-rpc/capabilities/x402 and the x402 section of https://docs.goldsky.com/feeds/api/overview. A user who has a Goldsky project should send the Feeds key instead.

## Writing code against a response

- Balances are the latest amount of each token, not a history. Several transfers in one block become one balance row. Reconstruct movement from the transfers feed.
- A transfer object has no id. Do not build a primary key that includes `block_number` or `block_timestamp`: a transaction that survives a reorg comes back with different block fields. Do not assume one transaction emits a transfer only once.
- `price_usd` and `amount_usd` are computed when the request is served. A later read of the same transfer can show a different USD value.
